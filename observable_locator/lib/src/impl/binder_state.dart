import 'package:mobx/mobx.dart';

import '../api.dart';
import '../binders.dart';
import '../exceptions.dart';

class BinderStateImpl<T, S> implements BinderState<T> {
  BinderStateImpl({
    required this.computedState,
    required this.observeFrom,
    required this.disposeState,
    required this.pendingValue,
    required this.catchError,
    required this.equals,
    required this.disposeValue,
    required this.key,
  });

  final S Function(T? currentValue, S? currentState) computedState;
  final T? Function(S computedState) observeFrom;
  final void Function(S computedState)? disposeState;

  final T? pendingValue;
  final ErrorBuilder<T>? catchError;
  final Equals<T>? equals;
  final DisposeCallback<T>? disposeValue;
  final Object key;

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

  @override
  T? tryObserve() {
    try {
      final oldValue = value;
      final newValue = _tryObserveComputed.value;

      if (newValue != null && oldValue != null) {
        final equals = this.equals ?? _defaultEquals;
        if (!equals(newValue, oldValue)) {
          disposeValue?.call(oldValue);
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

  @override
  T observe() {
    final newValue = tryObserve();

    if (!_isNullSafe(newValue)) {
      throw LocatorValueMissingException(key);
    }

    return newValue as T;
  }

  @override
  void dispose() {
    final value = this.value;
    if (value != null) disposeValue?.call(value);
    if (_hasState) disposeState?.call(_state.value);
  }
}
