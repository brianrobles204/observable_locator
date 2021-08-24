import 'package:mobx/mobx.dart';

/// ** HASH UTILITIES ** ///

/// Jenkins hash function, optimized for small integers.
//
// Borrowed from the dart sdk: sdk/lib/math/jenkins_smi_hash.dart.
class _Jenkins {
  static int combine(int hash, Object? o) {
    assert(o is! Iterable);
    hash = 0x1fffffff & (hash + o.hashCode);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

final int kEmptyHash = hashList([]);

/// Combine the [Object.hashCode] values of an arbitrary number of objects from
/// an [Iterable] into one value. This function will return the same value if
/// given null as if given an empty list.
int hashList(Iterable<Object?>? arguments) {
  var result = 0;
  if (arguments != null) {
    for (final argument in arguments) {
      result = _Jenkins.combine(result, argument);
    }
  }
  return _Jenkins.finish(result);
}

/// ** MOBX UTILITIES ** ///

Object unwrapError(Object error) =>
    error is MobXCaughtException ? error.exception : error;

V unwrapValue<V>(V Function() fn) {
  try {
    return fn();
  } catch (e) {
    throw unwrapError(e);
  }
}

extension UnwrapValueExtension<T> on ObservableValue<T> {
  T get unwrappedValue => unwrapValue(() => value);
}
