import 'package:mobx/mobx.dart';

import 'utils.dart';
import '../api.dart';
import '../binders.dart';
import '../exceptions.dart';

class BinderStateImpl<T, S> implements BinderState<T> {
  BinderStateImpl({
    required this.computeState,
    required this.observeFrom,
    required this.disposeState,
    required this.pendingValue,
    required this.catchError,
    required this.equals,
    required this.disposeValue,
    required this.key,
    required ObservableLocator locator,
  }) {
    _stateTracker = _StateTracker(
      locator: locator,
      fn: (source) => computeState(source, _value, _state),
    );
  }

  BinderStateImpl._cloneFrom({
    required ObservableLocator locator,
    required BinderStateImpl<T, S> parent,
  })  : computeState = parent.computeState,
        observeFrom = parent.observeFrom,
        disposeState = parent.disposeState,
        pendingValue = parent.pendingValue,
        catchError = parent.catchError,
        equals = parent.equals,
        disposeValue = parent.disposeValue,
        key = parent.key,
        _stateTracker = _StateTracker.cloneFrom(
          locator: locator,
          parent: parent._stateTracker,
          parentState: parent,
        );

  /// Callback for creating the state that holds the current value.
  ///
  /// Any observables read within the callback will be tracked. If any dependent
  /// observable values change, the state and value will be recomputed again,
  /// similar to a [Computed] `fn` callback.
  final S Function(
    ObservableSource locator,
    T? currentValue,
    S? currentState,
  ) computeState;

  /// Callback that reads the value from the current state.
  ///
  /// This should typically report a read / observation to the surrounding
  /// MobX reactive context, similar to a [Computed.value] call.
  final T? Function(S computedState) observeFrom;

  /// Optional callback that can be used to clean-up the current state.
  ///
  /// Called during [dispose].
  final void Function(S computedState)? disposeState;

  final T? pendingValue;
  final ErrorBuilder<T>? catchError;
  final Equals<T>? equals;
  final DisposeCallback<T>? disposeValue;

  late final _StateTracker<S> _stateTracker;
  final Object key;

  bool _hasProducedValue = false;
  T? _value;
  S? _state;

  Computed<S> get _stateComputed =>
      (__stateComputed ??= Computed(_stateFn, name: 'BinderState<$T>.state'));
  Computed<S>? __stateComputed;
  bool get _hasState => __stateComputed != null;

  S _stateFn() {
    final newState = unwrapValue(() => _stateTracker.value);

    if (newState != _state) {
      _state = newState;
      _hasProducedValue = false;
    }

    return newState;
  }

  static bool _defaultEquals<T>(T? newValue, T? oldValue) =>
      newValue == oldValue;

  Computed<T?> get _valueComputed => __valueComputed ??= Computed(
        _valueFn,
        equals: equals ?? _defaultEquals,
        name: 'BinderState<$T>.value',
      );
  Computed<T?>? __valueComputed;

  T? _valueFn() {
    final newValue = () {
      try {
        return observeFrom(_stateComputed.value);
      } catch (e) {
        final catchError = this.catchError;
        if (catchError != null) {
          return catchError.call(e);
        } else {
          throw unwrapError(e);
        }
      }
    }();

    final result = newValue ?? (!_hasProducedValue ? pendingValue : null);
    _hasProducedValue = true;

    return result;
  }

  @override
  T? tryObserve() {
    try {
      final oldValue = _value;
      final newValue = _valueComputed.value;

      if (newValue != null && oldValue != null) {
        final equals = this.equals ?? _defaultEquals;
        if (!equals(newValue, oldValue)) {
          disposeValue?.call(oldValue);
        }
      }

      _value = newValue;
      return newValue;
    } catch (e) {
      throw unwrapError(e);
    }
  }

  bool _isNullSafe(T? value) {
    Type typeOf<N>() => N;
    final isNullable = T == typeOf<T?>();

    return isNullable || value != null;
  }

  @override
  T observe() {
    final newValue = tryObserve();

    if (!_isNullSafe(newValue)) {
      throw LocatorValueMissingException(key);
    }

    return newValue as T;
  }

  @override
  BinderState<T> cloneWith(ObservableLocator locator) =>
      BinderStateImpl._cloneFrom(locator: locator, parent: this);

  @override
  void dispose() {
    final value = _value;
    if (value != null) disposeValue?.call(value);
    if (_hasState) disposeState?.call(untracked<S>(() => _stateComputed.value));
  }
}

typedef _SourceFn<V> = V Function(ObservableSource source);

/// [Computed]-like tracker for state `S` within a [BinderStateImpl].
///
/// Tracks observable dependencies used while creating the state, but not calls
/// to [ObservableSource.observeKey]. The source observe calls are then tracked
/// separately to allow sharing of states or creation of different states
/// based on the values within the provided locator.
class _StateTracker<S> {
  _StateTracker({
    required this.locator,
    required this.fn,
    this.equals,
  })  : keys = {},
        _derivedFromParent = false,
        _isDirty = true {
    tracker = Computed(
      () {
        try {
          _isDirty = true;
          return _trackValue();
        } catch (_) {
          // rely on observables only if an error occured
          _updateObservableHash();
          rethrow;
        }
      },
      name: 'BinderState.tracker-main<$S>',
      equals: (_, __) => false,
    );
    _value = Computed(
      () {
        try {
          if (_isDirty) {
            // Update due to new value from the tracker
            return tracker.unwrappedValue;
          } else {
            // Update due to observables change

            // subscribe to tracker but don't use its outdated value
            // should return the cached value without recomputation
            tracker.unwrappedValue;

            // return fresh value, but don't track to avoid unecessary updates
            return untracked(() => _trackValue());
          }
        } finally {
          _updateObservableHash();
          _isDirty = false;
        }
      },
      name: 'BinderState.trackerValue-main<$S>',
      equals: equals,
    );
  }

  _StateTracker.cloneFrom({
    required this.locator,
    required _StateTracker<S> parent,
    required BinderStateImpl<dynamic, S> parentState,
  })  : keys = Set.of(parent.keys),
        tracker = parent.tracker,
        fn = parent.fn,
        equals = parent.equals,
        _derivedFromParent = true,
        _isDirty = false {
    S _observeOwnValue() {
      try {
        _derivedFromParent = false;
        return _trackValue();
      } finally {
        _updateObservableHash();
      }
    }

    _value = Computed(
      () {
        if (_derivedFromParent && parent._observableHash == _observeHash()) {
          // If deriving from parent and observables are the same,
          // watch the tracker and observables
          late S parentValue;
          Object? error;
          try {
            keys.clear();
            tracker.unwrappedValue;
            parentValue = untracked(
              () => unwrapValue(() {
                // Force evaluation of parent value.
                // Ensures previous state and value of parent are available.
                parentState.tryObserve();
                return parentState._stateComputed.value;
              }),
            );
          } catch (e) {
            error = e;
          } finally {
            keys.addAll(parent.keys);
            _updateObservableHash();
          }

          if (parent._observableHash != _observableHash) {
            // We don't actually match after trying parent, rely on own value
            return _observeOwnValue();
          } else {
            if (error != null) {
              throw error;
            } else {
              return parentValue;
            }
          }
        } else {
          return _observeOwnValue();
        }
      },
      equals: equals,
      name: 'BinderState.trackerValue-clone<$S>',
    );
  }

  final ObservableLocator locator;
  final Set<Object> keys;
  final _SourceFn<S> fn;
  final Equals<S>? equals;
  late final Computed<S> tracker;

  int _observableHash = kEmptyHash;
  bool _derivedFromParent;
  bool _isDirty;

  S get value => _value.value;
  late final Computed<S> _value;

  late final _ProxyObservableSource _source = _ProxyObservableSource(
    locator: locator,
    onObserve: (key) => keys.add(key),
  );

  S _trackValue() {
    keys.clear();
    return _source.readInBatch(fn); // repopulates keys when observed
  }

  void _updateObservableHash() => _observableHash = _observeHash();
  int _observeHash() {
    return hashList(<dynamic>[
      for (final key in keys)
        () {
          try {
            return locator.observeKey(key);
          } catch (e) {
            return e;
          }
        }(),
    ]);
  }
}

class _ProxyObservableSource implements ObservableSource {
  _ProxyObservableSource({
    required this.locator,
    required this.onObserve,
  });

  final ObservableLocator locator;
  final void Function(Object key) onObserve;

  bool isInBatch = false;

  @override
  T observeKey<T>(Object key) {
    assert(isInBatch);
    onObserve(key);
    return untracked(() => locator.observeKey(key));
  }

  @override
  T? tryObserveKey<T>(Object key) {
    assert(isInBatch);
    onObserve(key);
    return untracked(() => locator.tryObserveKey(key));
  }

  V readInBatch<V>(_SourceFn<V> fn) {
    assert(!isInBatch);
    try {
      isInBatch = true;
      return fn(this);
    } finally {
      isInBatch = false;
    }
  }
}
