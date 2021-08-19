import 'impl.dart';

typedef RequireCheck<T> = bool Function(T? value);

abstract class ObservableLocator {
  ObservableLocator._();

  static WritableObservableLocator writable() => ObservableLocatorImpl();

  T observe<T>();
  T? tryObserve<T>();

  ObservableLocator? get parent;
  List<ObservableLocator> get children;
  WritableObservableLocator createChild();

  void dispose();
}

typedef ValueBuilder<T> = T Function(T? oldvalue);

typedef FutureValueBuilder<T> = Future<T> Function(
  T? oldValue,
  Future<T>? oldFuture,
);

typedef StreamValueBuilder<T> = Stream<T> Function(
  T? oldValue,
  Stream<T>? oldStream,
);

typedef ErrorBuilder<T> = T Function(Object error);
typedef Equals<T> = bool Function(T? newValue, T? oldValue);
typedef DisposeCallback<T> = void Function(T value);

abstract class WritableObservableLocator extends ObservableLocator {
  WritableObservableLocator._() : super._();

  void register<T>(
    ValueBuilder<T> fn, {
    ErrorBuilder<T>? catchError,
    Equals<T>? equals,
    DisposeCallback<T>? dispose,
  });

  void registerFuture<T>(
    FutureValueBuilder<T> fn, {
    T? pendingValue,
    ErrorBuilder<T>? catchError,
    Equals<T>? equals,
    DisposeCallback<T>? dispose,
  });

  void registerStream<T>(
    StreamValueBuilder<T> fn, {
    T? pendingValue,
    ErrorBuilder<T>? catchError,
    Equals<T>? equals,
    DisposeCallback<T>? dispose,
  });
}
