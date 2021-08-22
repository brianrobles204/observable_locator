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
    return 'Observable Locator Error: '
        'The given key "$key" was not found.';
  }
}
