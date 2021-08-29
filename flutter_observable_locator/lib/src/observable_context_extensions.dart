import 'package:flutter/widgets.dart';
import 'package:observable_locator/observable_locator.dart';

import 'observable_locator_scope.dart';

/// Extensions on the context to easily observe a value from the nearest
/// surrounding [ObservableLocatorScope].
extension ObservableContextExtensions on BuildContext {
  T observe<T>({bool listen = true}) =>
      ObservableLocatorScope.of(this, listen: listen).observe<T>();

  T? tryObserve<T>({bool listen = true}) =>
      ObservableLocatorScope.of(this, listen: listen).tryObserve<T>();
}
