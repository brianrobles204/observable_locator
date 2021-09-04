import 'package:meta/meta.dart';
import 'package:mobx/mobx.dart';

import 'utils.dart';
import '../api.dart';
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
    this.stateEquals,
  }) : _wasDerivedFromParent = false {
    _stateTracker = _ParentStateTracker(
      locator: locator,
      fn: (source) => computeState(source, _value, _state),
      equals: stateEquals,
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
        stateEquals = parent.stateEquals,
        _wasDerivedFromParent = true,
        _stateTracker = _ChildStateTracker(
          locator: locator,
          parent: parent._stateTracker,
          parentBinder: parent,
        );

  /// Callback for creating the state that holds the current value.
  ///
  /// Any observables read within the callback will be tracked. If any dependent
  /// observable values change, the state and value will be recomputed again,
  /// similar to a [Computed] `fn` callback.
  final StateBuilder<T, S> computeState;

  /// Callback that reads the value from the current state.
  ///
  /// This should typically report a read / observation to the surrounding
  /// MobX reactive context, similar to a [Computed.value] call.
  final ObserveCallback<T, S> observeFrom;

  /// Optional callback that can be used to clean-up the current state.
  ///
  /// Called during [dispose].
  final DisposeCallback<S>? disposeState;

  final T? pendingValue;
  final ErrorBuilder<T>? catchError;
  final Equals<T>? equals;
  final Equals<S>? stateEquals;
  final DisposeCallback<T>? disposeValue;

  late final _StateTracker<S> _stateTracker;
  final Object key;

  bool _wasDerivedFromParent;
  bool _hasProducedValue = false;
  T? _value;
  S? _state;

  late final Computed<S> _stateComputed =
      Computed(_stateFn, equals: stateEquals, name: 'BinderState<$T>.state');

  S _stateFn() {
    final newState = unwrapValue(() => _stateTracker.state);

    final equals = stateEquals ?? _defaultEquals;
    if (!equals(newState, _state)) {
      _tryDispose(_state, disposeState);
      _state = newState;
      _hasProducedValue = false;
    }

    return newState;
  }

  static bool _defaultEquals<T>(T? newValue, T? oldValue) =>
      newValue == oldValue;

  late final Computed<T?> _valueComputed = Computed(
    _valueFn,
    equals: equals ?? _defaultEquals,
    name: 'BinderState<$T>.value',
  );

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

  bool _isNullSafe(T? value) {
    Type typeOf<N>() => N;
    final isNullable = T == typeOf<T?>();

    return isNullable || value != null;
  }

  @override
  T observe() {
    try {
      final oldValue = _value;
      final newValue = _valueComputed.value;

      if (newValue != null && oldValue != null) {
        final equals = this.equals ?? _defaultEquals;
        if (!equals(newValue, oldValue) && !equals(pendingValue, _value)) {
          _tryDispose(_value, disposeValue);
        }
      }

      _value = newValue;
      _wasDerivedFromParent = _stateTracker.isDerivedFromParent;

      if (!_isNullSafe(newValue)) {
        throw LocatorValueMissingException(key);
      }

      return newValue as T;
    } catch (e) {
      throw unwrapError(e);
    }
  }

  @override
  BinderState<T> cloneWith(ObservableLocator locator) =>
      BinderStateImpl._cloneFrom(locator: locator, parent: this);

  @override
  void dispose() {
    _tryDispose(_state, disposeState);
    _tryDispose(_value, disposeValue);
  }

  void _tryDispose<D>(D? disposable, DisposeCallback<D>? disposeFn) {
    if (!_wasDerivedFromParent && disposable != null) {
      disposeFn?.call(disposable);
    }
  }
}

typedef _SourceFn<V> = V Function(ObservableSource source);

/// [Computed]-like tracker for state `S` within a [BinderStateImpl].
///
/// To facilitate optional sharing of state between parent and child, the base
/// class provides methods for computing state, [computeState], without
/// subscribing to updates from the [ObservableLocator]. Instead, locator
/// dependencies can be subscribed separately via [observeAndUpdateHash].
///
/// This allows for children state whose values are derived from a parent, but
/// whose values can also be updated based on observing child locators.
abstract class _StateTracker<S> {
  _StateTracker({
    required this.locator,
    required this.fn,
    required this.keys,
    this.equals,
  });

  final ObservableLocator locator;
  final _SourceFn<S> fn;
  final Equals<S>? equals;

  final Set<Object> keys;

  late final _NonLocatorSource _nonLocatorSource = _NonLocatorSource(locator);

  /// Should return the observable computed state that tracks both locator and
  /// non-locator observe calls.
  ///
  /// Typically, this should return the result of [Computed.value], where the
  /// value is calculated using [computeState] and [observeAndUpdateHash].
  S get state;

  /// Whether the state is derived from a parent [_StateTracker].
  bool get isDerivedFromParent;

  /// Computes new state.
  ///
  /// Does not track any locator.observe calls. Instead, the keys used during
  /// each observe call are saved in [keys]. Other non-locator observable value
  /// reads are still tracked.
  ///
  /// Note that the locator hash (which uses the updated [keys]) still needs to
  /// be observed and updated separately via [observeAndUpdateHash].
  @protected
  S computeState() {
    keys.clear();
    return _nonLocatorSource.read(fn, onLocatorObserve: (key) => keys.add(key));
  }

  int get locatorHash => _locatorHash;
  int _locatorHash = kEmptyHash;

  @protected
  void observeAndUpdateHash() => _locatorHash = _observeHash();

  @protected
  int untrackedHash() => untracked(() => _observeHash());

  int _observeHash() {
    return hashList(<dynamic>[
      for (final key in keys) ...[key, _locatorValueFrom(key)]
    ]);
  }

  dynamic _locatorValueFrom(Object key) {
    try {
      return locator.observeKey(key);
    } catch (e) {
      return e;
    }
  }
}

/// StateTracker whose state simply updates whenever any locator or non-locator
/// observable value changes.
class _ParentStateTracker<S> extends _StateTracker<S> {
  _ParentStateTracker({
    required ObservableLocator locator,
    required _SourceFn<S> fn,
    Equals<S>? equals,
  }) : super(locator: locator, fn: fn, equals: equals, keys: {});

  @override
  bool get isDerivedFromParent => false;

  @override
  S get state => _state.value;
  late final Computed<S> _state = Computed<S>(
    () {
      try {
        return computeState();
      } finally {
        observeAndUpdateHash();
      }
    },
    name: '_ParentStateTracker<$S>.state',
    equals: equals,
  );
}

/// StateTracker whose state can be derived from a parent state.
///
/// Will try to use parent state if the values of all parent locator observe
/// calls are equal to the values of all child locator observe calls (by
/// comparing hash codes).
///
/// If locator values are equal, the class will defer to the parent state. If
/// not, the class will instead manage and track its own state.
class _ChildStateTracker<T, S> extends _StateTracker<S> {
  _ChildStateTracker({
    required ObservableLocator locator,
    required this.parent,
    required this.parentBinder,
  }) : super(
          locator: locator,
          fn: parent.fn,
          keys: Set.of(parent.keys),
          equals: parent.equals,
        );

  final _StateTracker<S> parent;
  final BinderStateImpl<T, S> parentBinder;

  @override
  bool get isDerivedFromParent => _isDerivedFromParent;
  bool _isDerivedFromParent = true;

  S _observeOwnState() {
    try {
      _isDerivedFromParent = false;
      return computeState();
    } finally {
      observeAndUpdateHash();
    }
  }

  @override
  S get state => _state.value;
  late final _state = Computed<S>(
    () {
      if (isDerivedFromParent && parent.locatorHash == untrackedHash()) {
        // If deriving from parent, and locator values are the same,
        // watch the parent non-locator state and use the parent value.
        late S parentState;
        Object? parentError;
        try {
          keys.clear();
          parentState = untracked(
            () => unwrapValue(() {
              // Force evaluation of parent value.
              // Ensures previous state and value of parent are available.
              try {
                parentBinder.observe();
              } finally {
                return parentBinder._stateComputed.value;
              }
            }),
          );
        } catch (e) {
          parentError = e;
        } finally {
          keys.addAll(parent.keys);
        }

        // Evaluation of parent state could have changed the locator values
        if (parent.locatorHash != untrackedHash()) {
          // We don't actually match after trying parent, rely on own state
          return _observeOwnState();
        } else {
          observeAndUpdateHash();
          unwrapValue(() => parent.state); // Subscribe to parent state
          if (parentError != null) {
            throw parentError;
          } else {
            return parentState;
          }
        }
      } else {
        return _observeOwnState();
      }
    },
    equals: equals,
    name: '_ChildStateTracker<$T,$S>.state',
  );
}

typedef OnObserveCallback = void Function(Object key);

/// Observable source that uses the provided locator to retrieve values but
/// ensures no tracking of [ObservableLocator.observeKey] calls. Instead, any
/// observe calls are forwarded to the [onObserve] callback.
class _NonLocatorSource implements ObservableSource {
  _NonLocatorSource(this.locator);

  final ObservableLocator locator;

  OnObserveCallback? onObserve;

  @override
  T observeKey<T>(Object key) => _observe(key, () => locator.observeKey(key));

  @override
  T? tryObserveKey<T>(Object key) =>
      _observe(key, () => locator.tryObserveKey(key));

  T _observe<T>(Object key, T Function() getValue) {
    if (onObserve == null) {
      throw LocatorUsedOutsideCallbackException(key);
    }

    onObserve!(key);
    return untracked(getValue);
  }

  V read<V>(_SourceFn<V> fn, {required OnObserveCallback onLocatorObserve}) {
    assert(onObserve == null);
    try {
      onObserve = onLocatorObserve;
      return fn(this);
    } finally {
      onObserve = null;
    }
  }
}
