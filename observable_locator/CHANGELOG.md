## 0.2.0 - 0.2.3

- Breaking API Changes
    - Types are registered on locator creation by passing in a list of Binder objects. Registering further values after locator creation is no longer supported.
    - Locators are now passed into the binder callback. Children locators can override the values and binders defined by parent locators can use the overriden values defined in the children.

## 0.1.0

- Initial release of Observable Locator, a service locator that uses MobX for reactive dependencies
