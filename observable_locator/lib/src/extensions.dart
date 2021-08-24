import 'api.dart';

extension ObserveTypeExtensions on ObservableSource {
  T observe<T>() {
    assert(T != dynamic, 'Tried to observe value of dynamic type');
    return observeKey(T);
  }

  T? tryObserve<T>() {
    assert(T != dynamic, 'Tried to observe value of dynamic type');
    return tryObserveKey(T);
  }
}
