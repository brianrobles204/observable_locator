import 'package:meta/meta.dart';

import 'impl/binder_state.dart';
import 'impl/observable_locator.dart';

typedef ErrorBuilder<T> = T Function(Object error);
typedef Equals<T> = bool Function(T? newValue, T? oldValue);
typedef DisposeCallback<T> = void Function(T value);

typedef ValueBuilder<T> = T Function(ObservableSource locator, T? oldvalue);
typedef StateBuilder<T, S> = S Function(
  ObservableSource locator,
  T? currentValue,
  S? currentState,
);

typedef ObserveCallback<T, S> = T? Function(S computedState);

abstract class Binder<T> {
  const Binder();

  Object get key;
  BinderState<T> createState(ObservableLocator locator);

  @nonVirtual
  Type get bindType => T;
}

abstract class BinderState<T> {
  static BinderState<T> create<T, S>({
    required StateBuilder<T, S> computeState,
    required ObserveCallback<T, S> observeFrom,
    DisposeCallback<S>? disposeState,
    T? pendingValue,
    ErrorBuilder<T>? catchError,
    Equals<T>? equals,
    DisposeCallback<T>? disposeValue,
    required Object key,
    required ObservableLocator locator,
  }) =>
      BinderStateImpl(
        computeState: computeState,
        observeFrom: observeFrom,
        disposeState: disposeState,
        pendingValue: pendingValue,
        catchError: catchError,
        equals: equals,
        disposeValue: disposeValue,
        key: key,
        locator: locator,
      );

  T observe();
  T? tryObserve();

  BinderState<T> cloneWith(ObservableLocator locator);

  @mustCallSuper
  void dispose();
}

abstract class ObservableSource {
  T observeKey<T>(Object key);
  T? tryObserveKey<T>(Object key);
}

abstract class ObservableLocator implements ObservableSource {
  factory ObservableLocator([Iterable<Binder> binders]) = ObservableLocatorImpl;

  ObservableLocator? get parent;
  List<ObservableLocator> get children;
  ObservableLocator createChild([Iterable<Binder> binders = const []]);

  @mustCallSuper
  void dispose();
}
