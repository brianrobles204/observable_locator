import 'package:meta/meta.dart';

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
  BinderState<T> createState(ObservableLocator locator);
}

abstract class BinderState<T> {
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
  factory ObservableLocator(Iterable<Binder> binders) = ObservableLocatorImpl;

  ObservableLocator? get parent;
  List<ObservableLocator> get children;
  ObservableLocator createChild(Iterable<Binder> binders);

  @mustCallSuper
  void dispose();
}
