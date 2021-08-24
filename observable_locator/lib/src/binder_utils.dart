import 'api.dart';
import 'binders.dart';

typedef SingleValueBuilder<T> = T Function();

Binder<T> single<T>(
  SingleValueBuilder<T> fn, {
  ErrorBuilder<T>? catchError,
  Equals<T>? equals,
  DisposeCallback<T>? dispose,
}) =>
    Binder(
      (_, __) => fn(),
      catchError: catchError,
      equals: equals,
      dispose: dispose,
    );

Binder<T> singleFuture<T>(
  SingleValueBuilder<Future<T>> fn, {
  T? pendingValue,
  ErrorBuilder<T>? catchError,
  Equals<T>? equals,
  DisposeCallback<T>? dispose,
}) =>
    FutureBinder(
      (_, __, ___) => fn(),
      pendingValue: pendingValue,
      catchError: catchError,
      equals: equals,
      dispose: dispose,
    );

Binder<T> singleStream<T>(
  SingleValueBuilder<Stream<T>> fn, {
  T? pendingValue,
  ErrorBuilder<T>? catchError,
  Equals<T>? equals,
  DisposeCallback<T>? dispose,
}) =>
    StreamBinder(
      (_, __, ___) => fn(),
      pendingValue: pendingValue,
      catchError: catchError,
      equals: equals,
      dispose: dispose,
    );
