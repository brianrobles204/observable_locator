## 0.3.0

- Minor changes but potentially breaking:
  - ValueBinder et. al. classes now accept a `key` as an argument. They now extend rather than implement `Binder`. Non-breaking if using binder top level utility functions.
  - tryObserve removed from BinderState interface.
- Other internal code changes. TryObserve has been rewritten to be in terms of observe, instead of being a separate code path.

## 0.2.5

- Bug fix: Bind callback updates due to locator value changes will now correctly subscribe to new observable values.

## 0.2.4

- Bug fix: Disposing a child locator should not dispose the value if the parent is still using it. Child locators will now only dispose their own values.
- Bug fix: Pending values will be disposed only when the locator is disposed, as they could reappear again if the future / stream is rebuilt.

## 0.2.0 - 0.2.3

- Breaking API Changes
    - Types are registered on locator creation by passing in a list of Binder objects. Registering further values after locator creation is no longer supported.
    - Locators are now passed into the binder callback. Children locators can override the values and binders defined by parent locators can use the overriden values defined in the children.

## 0.1.0

- Initial release of Observable Locator, a service locator that uses MobX for reactive dependencies
