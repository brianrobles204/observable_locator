import 'package:mobx/mobx.dart';

import 'api.dart';
import 'exceptions.dart';

class _ObservableValueDelegate<T, S> {
  _ObservableValueDelegate({
    required this.computedState,
    required this.observeFrom,
    required this.disposeState,
    required this.pendingValue,
    required this.catchError,
    required this.equals,
    required this.dispose,
  });

  final S Function(T? currentValue, S? currentState) computedState;
  final T? Function(S computedState) observeFrom;
  final void Function(S computedState)? disposeState;

  final T? pendingValue;
  final ErrorBuilder<T>? catchError;
  final Equals<T>? equals;
  final DisposeCallback<T>? dispose;

  bool hasProducedValue = false;
  T? value;

  S? _prevState;
  Computed<S>? __state;
  Computed<S> get _state => (__state ??= Computed(_computeNewState));
  bool get _hasState => __state != null;

  S _computeNewState() {
    final newState = computedState(value, _prevState);
    if (newState != _prevState) {
      _prevState = newState;
      hasProducedValue = false;
    }

    return newState;
  }

  static bool _defaultEquals<T>(T? newValue, T? oldValue) =>
      newValue == oldValue;

  Object _unwrapError(Object error) =>
      error is MobXCaughtException ? error.exception : error;

  late final Computed<T?> _tryObserveComputed = Computed(
    () {
      final newValue = () {
        try {
          return observeFrom(_state.value);
        } catch (e) {
          final catchError = this.catchError;
          if (catchError != null) {
            return catchError.call(e);
          } else {
            throw _unwrapError(e);
          }
        }
      }();

      final result = newValue ?? (!hasProducedValue ? pendingValue : null);
      hasProducedValue = true;

      return result;
    },
    equals: equals ?? _defaultEquals,
  );

  T? tryObserve() {
    try {
      final oldValue = value;
      final newValue = _tryObserveComputed.value;

      if (newValue != null && oldValue != null) {
        final equals = this.equals ?? _defaultEquals;
        if (!equals(newValue, oldValue)) {
          dispose?.call(oldValue);
        }
      }

      value = newValue;
      return newValue;
    } catch (e) {
      throw _unwrapError(e);
    }
  }

  bool _isNullSafe(T? value) {
    Type typeOf<N>() => N;
    final isNullable = T == typeOf<T?>();

    return isNullable || value != null;
  }

  T observe() {
    final newValue = tryObserve();

    if (!_isNullSafe(newValue)) {
      throw LocatorValueMissingException<T>();
    }

    return newValue as T;
  }

  void disposeDelegate() {
    final value = this.value;
    if (value != null) dispose?.call(value);

    if (_hasState) disposeState?.call(_state.value);
  }
}

class ObservableLocatorImpl implements WritableObservableLocator {
  ObservableLocatorImpl() : _parent = null;
  ObservableLocatorImpl._fromParent(this._parent);

  final Map<Type, _ObservableValueDelegate> _valueMap = {};
  final Map<Type, Atom> _atomMap = {};

  @override
  ObservableLocator? get parent => _parent;
  final ObservableLocatorImpl? _parent;

  @override
  List<ObservableLocator> get children => List.unmodifiable(_children);
  late final List<ObservableLocatorImpl> _children = [];

  bool _isDisposed = false;

  _ObservableValueDelegate<T, dynamic>? _delegateFor<T>() {
    assert(T != dynamic, 'Tried to observe value of dynamic type');
    return _valueMap[T] as _ObservableValueDelegate<T, dynamic>? ??
        _parent?._delegateFor<T>();
  }

  bool _debugCheckNotDisposed() {
    assert(() {
      if (_isDisposed) {
        throw StateError('The locator $this was '
            'used after being disposed.');
      }
      return true;
    }());
    return true;
  }

  @override
  T observe<T>() {
    assert(_debugCheckNotDisposed());
    final delegate = _delegateFor<T>();

    if (delegate != null) {
      return delegate.observe();
    } else {
      throw LocatorTypeNotRegisteredException<T>();
    }
  }

  @override
  T? tryObserve<T>() {
    assert(_debugCheckNotDisposed());
    final delegate = _delegateFor<T>();

    if (delegate != null) {
      try {
        return delegate.tryObserve();
      } catch (e) {
        return null;
      }
    } else {
      _atomMap[T] = Atom()..reportRead();
    }
  }

  void _ensureUnregistered<T>() {
    if (_valueMap.containsKey(T)) {
      throw LocatorValueAlreadyRegisteredException<T>();
    }
  }

  void _notifyTryObservers<T>() {
    final atom = _atomMap[T];

    if (atom != null) {
      atom.context.conditionallyRunInAction(() {
        _atomMap.remove(T);
        atom.reportChanged();
      }, atom);
    }
  }

  void _registerDelegate<T>(_ObservableValueDelegate<T, dynamic> delegate) {
    assert(_debugCheckNotDisposed());
    assert(T != dynamic, 'Tried to register dynamic type');

    _ensureUnregistered<T>();
    _valueMap[T] = delegate;
    _notifyTryObservers<T>();
  }

  @override
  void register<T>(
    ValueBuilder<T> fn, {
    ErrorBuilder<T>? catchError,
    Equals<T>? equals,
    DisposeCallback<T>? dispose,
  }) {
    _registerDelegate<T>(
      _ObservableValueDelegate<T, T>(
        computedState: (currentValue, _) => fn(currentValue),
        observeFrom: (computedState) => computedState,
        disposeState: null,
        pendingValue: null,
        catchError: catchError,
        equals: equals,
        dispose: dispose,
      ),
    );
  }

  @override
  void registerFuture<T>(
    FutureValueBuilder<T> fn, {
    T? pendingValue,
    ErrorBuilder<T>? catchError,
    Equals<T>? equals,
    DisposeCallback<T>? dispose,
  }) {
    _registerDelegate<T>(
      _ObservableValueDelegate<T, ObservableFuture<T>>(
        computedState: (currentValue, currentState) {
          final future = fn(currentValue, currentState);

          if (future is ObservableFuture<T>) return future;
          return future.asObservable();
        },
        observeFrom: (computedState) {
          if (computedState.error != null) throw computedState.error as Object;
          return computedState.value;
        },
        disposeState: null,
        pendingValue: pendingValue,
        catchError: catchError,
        equals: equals,
        dispose: dispose,
      ),
    );
  }

  @override
  void registerStream<T>(
    StreamValueBuilder<T> fn, {
    T? pendingValue,
    ErrorBuilder<T>? catchError,
    Equals<T>? equals,
    DisposeCallback<T>? dispose,
  }) {
    _registerDelegate<T>(
      _ObservableValueDelegate<T, ObservableStream<T>>(
        computedState: (currentValue, currentState) {
          final stream = fn(currentValue, currentState);

          if (stream is ObservableStream<T>) return stream;
          return stream.asObservable();
        },
        observeFrom: (computedState) {
          if (computedState.error != null) throw computedState.error as Object;
          if (computedState.status != StreamStatus.waiting) {
            return computedState.value;
          } else {
            return null;
          }
        },
        disposeState: null,
        pendingValue: pendingValue,
        catchError: catchError,
        equals: equals,
        dispose: dispose,
      ),
    );
  }

  @override
  WritableObservableLocator createChild() {
    assert(_debugCheckNotDisposed());

    final child = ObservableLocatorImpl._fromParent(this);
    _children.add(child);

    return child;
  }

  void _notifyChildDisposed(ObservableLocatorImpl child) {
    if (!_isDisposed) {
      assert(_children.contains(child));
      _children.remove(child);
    }
  }

  @override
  void dispose() {
    assert(_debugCheckNotDisposed());

    final delegates = List<_ObservableValueDelegate>.from(_valueMap.values);
    delegates.forEach((delegate) => delegate.disposeDelegate());

    final children = List<ObservableLocatorImpl>.from(_children);
    children.forEach((child) => child.dispose());
    _parent?._notifyChildDisposed(this);

    _valueMap.clear();
    _atomMap.clear();
    _children.clear();
    _isDisposed = true;
  }

  @override
  String toString() {
    return [
      'ObservableLocatorImpl { ',
      if (_parent != null) 'with parent, ',
      '${_children.length} children, ',
      '${_valueMap.length} registered values, ',
      '}'
    ].join();
  }
}
