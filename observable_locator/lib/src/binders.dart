import 'package:mobx/mobx.dart';

import 'api.dart';
import 'impl/binder_state.dart';

typedef ErrorBuilder<T> = T Function(Object error);
typedef Equals<T> = bool Function(T? newValue, T? oldValue);
typedef DisposeCallback<T> = void Function(T value);

typedef ValueBuilder<T> = T Function(ObservableSource locator, T? oldvalue);

mixin TypeKeyMixin<T> {
  Object get key {
    assert(T != dynamic, 'Tried to use dynamic type as key');
    return T;
  }
}

class ValueBinder<T> with TypeKeyMixin<T> implements Binder<T> {
  const ValueBinder(
    this.fn, {
    this.catchError,
    this.equals,
    this.dispose,
  });

  final ValueBuilder<T> fn;
  final ErrorBuilder<T>? catchError;
  final Equals<T>? equals;
  final DisposeCallback<T>? dispose;

  @override
  BinderState<T> createState(ObservableLocator locator) =>
      BinderStateImpl<T, T>(
        computeState: (locator, currentValue, _) => fn(locator, currentValue),
        observeFrom: (computedState) => computedState,
        disposeState: null,
        pendingValue: null,
        catchError: catchError,
        equals: equals,
        disposeValue: dispose,
        locator: locator,
        key: key,
      );
}

typedef FutureValueBuilder<T> = Future<T> Function(
  ObservableSource locator,
  T? oldValue,
  Future<T>? oldFuture,
);

class FutureBinder<T> with TypeKeyMixin<T> implements Binder<T> {
  const FutureBinder(
    this.fn, {
    this.pendingValue,
    this.catchError,
    this.equals,
    this.dispose,
  });

  final FutureValueBuilder<T> fn;
  final T? pendingValue;
  final ErrorBuilder<T>? catchError;
  final Equals<T>? equals;
  final DisposeCallback<T>? dispose;

  @override
  BinderState<T> createState(ObservableLocator locator) =>
      BinderStateImpl<T, ObservableFuture<T>>(
        computeState: (locator, currentValue, currentState) {
          final future = fn(locator, currentValue, currentState);

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
        disposeValue: dispose,
        locator: locator,
        key: key,
      );
}

typedef StreamValueBuilder<T> = Stream<T> Function(
  ObservableSource locator,
  T? oldValue,
  Stream<T>? oldStream,
);

class StreamBinder<T> with TypeKeyMixin<T> implements Binder<T> {
  const StreamBinder(
    this.fn, {
    this.pendingValue,
    this.catchError,
    this.equals,
    this.dispose,
  });

  final StreamValueBuilder<T> fn;
  final T? pendingValue;
  final ErrorBuilder<T>? catchError;
  final Equals<T>? equals;
  final DisposeCallback<T>? dispose;

  @override
  BinderState<T> createState(ObservableLocator locator) =>
      BinderStateImpl<T, ObservableStream<T>>(
        computeState: (locator, currentValue, currentState) {
          final stream = fn(locator, currentValue, currentState);

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
        disposeValue: dispose,
        locator: locator,
        key: key,
      );
}
