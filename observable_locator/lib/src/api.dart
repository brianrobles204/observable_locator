import 'binders.dart';
import 'impl/observable_locator.dart';

abstract class Binder<T> {
  const factory Binder(
    ValueBuilder<T> fn, {
    ErrorBuilder<T>? catchError,
    Equals<T>? equals,
    DisposeCallback<T>? dispose,
  }) = ValueBinder;

  Object get key;
  BinderState<T> createState();
}

abstract class BinderState<T> {
  T observe();
  T? tryObserve();

  void dispose();
}

abstract class ObservableLocator {
  factory ObservableLocator(Iterable<Binder> binders) = ObservableLocatorImpl;

  T observeKey<T>(Object key);
  T? tryObserveKey<T>(Object key);

  ObservableLocator? get parent;
  List<ObservableLocator> get children;
  ObservableLocator createChild(Iterable<Binder> binders);

  void dispose();
}
