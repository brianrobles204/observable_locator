import 'package:mobx/mobx.dart';

import 'api.dart';

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
      BinderState.create<T, T>(
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

class FutureBinder<T> with TypeKeyMixin<T> implements Binder<T> {
  const FutureBinder(
    this.fn, {
    this.pendingValue,
    this.catchError,
    this.equals,
    this.dispose,
    this.name,
  });

  final StateBuilder<T, Future<T>> fn;
  final T? pendingValue;
  final ErrorBuilder<T>? catchError;
  final Equals<T>? equals;
  final DisposeCallback<T>? dispose;
  final String? name;

  @override
  BinderState<T> createState(ObservableLocator locator) =>
      BinderState.create<T, ObservableFuture<T>>(
        computeState: (locator, currentValue, currentState) {
          final future = fn(locator, currentValue, currentState);

          if (future is ObservableFuture<T>) return future;
          return future.asObservable(
            name: name != null ? 'FutureBinder<$T>@$name' : 'FutureBinder<$T>',
          );
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
    this.name,
  });

  final StateBuilder<T, Stream<T>> fn;
  final T? pendingValue;
  final ErrorBuilder<T>? catchError;
  final Equals<T>? equals;
  final DisposeCallback<T>? dispose;
  final String? name;

  @override
  BinderState<T> createState(ObservableLocator locator) =>
      BinderState.create<T, ObservableStream<T>>(
        computeState: (locator, currentValue, currentState) {
          final stream = fn(locator, currentValue, currentState);

          if (stream is ObservableStream<T>) return stream;
          return stream.asObservable(
            name: name != null ? 'StreamBinder<$T>@$name' : 'StreamBinder<$T>',
          );
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
