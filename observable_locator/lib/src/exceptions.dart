class LocatorValueMissingException implements Exception {
  LocatorValueMissingException(this.key);

  final Object key;

  @override
  String toString() {
    return 'Observable Locator Exception: '
        'The given key "$key" does not have a value within the locator.';
  }
}

class LocatorValueAlreadyRegisteredException implements Exception {
  LocatorValueAlreadyRegisteredException(this.key);

  final Object key;

  @override
  String toString() {
    return 'Observable Locator Exception: '
        'The given key "$key" is already registered within the locator.';
  }
}

class LocatorKeyNotFoundException implements Exception {
  LocatorKeyNotFoundException(this.key);

  final Object key;

  @override
  String toString() {
    return 'Observable Locator Exception: '
        'The given key "$key" was not found.';
  }
}

class LocatorUsedOutsideCallbackException implements Exception {
  LocatorUsedOutsideCallbackException(this.key);

  final Object key;

  @override
  String toString() {
    return 'Observable Locator Exception: '
        'Tried to read the key "$key" from a bind() ObservableSource '
        'while outside the bind callback.';
  }
}
