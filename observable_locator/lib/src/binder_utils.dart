import 'api.dart';
import 'binders.dart';

typedef SingleValueBuilder<T> = T Function();
typedef BindValueBuilder<T> = T Function(ObservableSource source);

Binder<T> single<T>(
  SingleValueBuilder<T> fn, {
  ErrorBuilder<T>? catchError,
  Equals<T>? equals,
  DisposeCallback<T>? dispose,
}) =>
    ValueBinder(
      (_, __) => fn(),
      key: T,
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
  String? name,
}) =>
    FutureBinder(
      (_, __, ___) => fn(),
      key: T,
      pendingValue: pendingValue,
      catchError: catchError,
      equals: equals,
      dispose: dispose,
      name: name,
    );

Binder<T> singleStream<T>(
  SingleValueBuilder<Stream<T>> fn, {
  T? pendingValue,
  ErrorBuilder<T>? catchError,
  Equals<T>? equals,
  DisposeCallback<T>? dispose,
  String? name,
}) =>
    StreamBinder(
      (_, __, ___) => fn(),
      key: T,
      pendingValue: pendingValue,
      catchError: catchError,
      equals: equals,
      dispose: dispose,
      name: name,
    );

Binder<T> bind<T>(
  BindValueBuilder<T> fn, {
  ErrorBuilder<T>? catchError,
  Equals<T>? equals,
  DisposeCallback<T>? dispose,
}) =>
    ValueBinder(
      (locator, __) => fn(locator),
      key: T,
      catchError: catchError,
      equals: equals,
      dispose: dispose,
    );

Binder<T> bindFuture<T>(
  BindValueBuilder<Future<T>> fn, {
  T? pendingValue,
  ErrorBuilder<T>? catchError,
  Equals<T>? equals,
  DisposeCallback<T>? dispose,
  String? name,
}) =>
    FutureBinder(
      (locator, __, ___) => fn(locator),
      key: T,
      pendingValue: pendingValue,
      catchError: catchError,
      equals: equals,
      dispose: dispose,
      name: name,
    );

Binder<T> bindStream<T>(
  BindValueBuilder<Stream<T>> fn, {
  T? pendingValue,
  ErrorBuilder<T>? catchError,
  Equals<T>? equals,
  DisposeCallback<T>? dispose,
  String? name,
}) =>
    StreamBinder(
      (locator, __, ___) => fn(locator),
      key: T,
      pendingValue: pendingValue,
      catchError: catchError,
      equals: equals,
      dispose: dispose,
      name: name,
    );

Binder<T> bindValue<T>(
  ValueBuilder<T> fn, {
  ErrorBuilder<T>? catchError,
  Equals<T>? equals,
  DisposeCallback<T>? dispose,
}) =>
    ValueBinder(
      fn,
      key: T,
      catchError: catchError,
      equals: equals,
      dispose: dispose,
    );

Binder<T> bindFutureValue<T>(
  StateBuilder<T, Future<T>> fn, {
  T? pendingValue,
  ErrorBuilder<T>? catchError,
  Equals<T>? equals,
  DisposeCallback<T>? dispose,
  String? name,
}) =>
    FutureBinder(
      fn,
      key: T,
      pendingValue: pendingValue,
      catchError: catchError,
      equals: equals,
      dispose: dispose,
      name: name,
    );

Binder<T> bindStreamValue<T>(
  StateBuilder<T, Stream<T>> fn, {
  T? pendingValue,
  ErrorBuilder<T>? catchError,
  Equals<T>? equals,
  DisposeCallback<T>? dispose,
  String? name,
}) =>
    StreamBinder(
      fn,
      key: T,
      pendingValue: pendingValue,
      catchError: catchError,
      equals: equals,
      dispose: dispose,
      name: name,
    );
