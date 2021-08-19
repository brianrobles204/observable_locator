class LocatorValueMissingException<T> implements Exception {
  LocatorValueMissingException();

  @override
  String toString() {
    return 'Observable Locator Exception: '
        'The given type "$T" does not have a value within the locator.';
  }
}

class LocatorValueAlreadyRegisteredException<T> implements Exception {
  LocatorValueAlreadyRegisteredException();

  @override
  String toString() {
    return 'Observable Locator Exception: '
        'The given type "$T" is already registered within the locator.';
  }
}

class LocatorTypeNotRegisteredException<T> implements Exception {
  LocatorTypeNotRegisteredException();

  @override
  String toString() {
    return 'Observable Locator Error: '
        'The given type "$T" is not registered.';
  }
}
