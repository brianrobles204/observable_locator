# Observable Locator

A service locator that uses [MobX](https://mobx.netlify.app/) to simplify 
the API and create reactive dependencies.

`Observable Locator` implements a service locator pattern for performing
dependency injection, similar to [get_it](https://pub.dev/packages/get_it) 
or [provider](https://pub.dev/packages/provider). However, like `provider`,
this package can be used to create dependencies that are reactive, using
MobX as the underlying system for reactivity. The API also makes it easy 
to create `async` dependencies (on futures & streams) with minimal boilerplate.

## How to use

### Basic Usage

You can create an observable locator like so:

```dart
var locator = ObservableLocator([
    // Expose a single value for each type
    single<String>(() => 'John Doe'),
    single<int>(() => 25),
]);
```

Locators are created by passing a list of `Binder` objects, that effectively 
define how values within the service locator are created and hooked up to 
each other.

It is customary to use the provided binder utility functions to create
the binders, such as `single`, `bind`, `bindValue`, etc.

To read from the locator, use the `observe()` function:

```dart
final name = locator.observe<String>();
final age = locator.observe<int>();
```

So far, things are similar to `get_it`. The key difference is that the
values inside the locator can change over time, and that values can depend
on other changing (i.e. *observable*) values. 

Under the hood, the locator uses `MobX` to implement this
reactivity. If you're unfamiliar with MobX, I suggest you read the 
[MobX documentation](https://mobx.netlify.app/). In a nutshell, MobX has
a concept of `observable` values and `reactions` with callback functions. 
When an observable value changes, any reactions that use the observable 
value are rerun. These reactions can have various side effects, from 
recomputing another value to rebuilding a Widget.

Calling `observe()` on the locator counts as reading an observable value
in MobX. Furthermore, binders behave like MobX `Computed` objects; they
can contain values which can update when other observable values change. 
The observable locator effectively works like a map of types to 
computed values.

See a more complex example:

```dart
var locator = ObservableLocator([
    // A single value
    single<Repository>(() => SqlRepository(version: 3)),

    // Value that can depend on another value
    bind<int>((locator) => locator.observe<Repository>().getVersion()),

    // Values that can change over time
    bindStream<User>((locator) => locator.observe<Repository>().getUserStream()),
]);

print(locator.observe<int>()); // prints `3`

// autorun is a MobX function that automatically runs when any 
// MobX observable value inside it is updated.
autorun(() {
    // prints the user's name every time a new user is emitted 
    // from the repository
    print(locator.observe<User>().name) 
});
```

The values in the observable locator behave like `Computed` objects. 

### Async values

Observable locator supports futures and stream values, similar to `provider`. 
Use the built-in binder utility functions:

```dart
var locator = ObservableLocator([
    // Values from futures
    singleFuture<Database>(
        () async => await Database.init(),
        dispose: (database) => database.close(),
    ),

    // Values from futures that can depend on other values
    bindFuture<Article>((locator) => locator.observe<Database>().getArticle()),

    // Values from streams
    singleStream<User>(
        () => User.streamUsers(),
        pendingValue: User.empty(),
        catchError: User.error(),
        equals: (a, b) => a.username == b.username,
    ),

    // Values from streams that can depend on other values
    bindStream<Comment>((locator) => locator.observe<User>().streamComments()),
]);
```

Reading async values is exactly the same as reading sync values:

```dart
final article = locator.observe<Article>();
final user = locator.observe<User>();
```

### Error handling

For future and stream valuse, if the `pendingValue` is `null` but the value's 
type is a non-null, then calling `observe()` will throw if the underlying 
stream / future hasn't emitted a value yet.

Additionally, if any errors are throws in the binder callback function for a 
type `T`, then that error is bubbled up and calling `observe<T>()` will also 
throw with the same error.

If throwing is undesired, use the `tryObserve<T>()` function which will return 
`null` instead of throwing.

### Putting it all together

The above behaviors are all intended, as they can be used to create async
dependencies with minimal boilerplate. Note the following example:

```dart
final locator = ObservableLocator([
    // A value dependency
    single<int>(() => 3),

    // Async dependencies
    singleFuture<Directory>(() => getApplicationDocumentsDirectory()),
    singleFuture<AppSecrets>(() => EnvironmentAppSecrets.init()),

    // A value that depends on both sync and async dependencies
    bind<Database>(
        (locator) => SqlDatabase(
            version: locator.observe<int>(),
            directory: locator.observe<Directory>(),
            filename: locator.observe<AppSecrets>().dbFilename,
        ),
    ),
    ...
]);
```

When you call `locator.observe<Database>()`, it will throw because its
dependencies aren't available yet. However, if you observe the `Database` 
from inside a reaction, it will also throw, but the reaction will rerun
again when the `Database` is actually ready.

In practice it will look like this:

```dart
// Prints 'Database is still loading' once, while the underlying 
// dependencies are loading. 
//
// Then finally prints the database once everything is done loading.
autorun(() {
    try {
        print(locator.observe<Database>());
    } catch (e) {
        print('Database is still loading');
    }
});
```

Under the hood, the locator will try to create an an `SqlDatabase` with 
the following steps:
- The first dependency, an `int`, will return `3` successfully.
- When `locator.observe<Directory>()` is called, the function throws because
the directory future has no value yet. This causes the original 
`locator.observe<Database>()` call to throw.
- However, when the future for the `Directory` dependency finally completes,
the `Database` callback is rerun again. This time, the `int` and `Directory`
dependencies return with a value, but `locator.observe<AppSecrets>()` throws
because the dependency has no value yet.
- Once the `AppSecrets` future completes, then the `Database` function reruns
and finally completes, since all dependencies are available.
- The original reaction that called `locator.observe<Database>()` is rerun
again and finally completes with a value.

Finally, you can combine the above behavior with the following pattern:

```dart
enum AppState { loading, ready }

final locator = ObservableLocator([
    ... // other binders

    bind<AppState>((locator) {
        try {
            // Observe all values that are needed for the app to run
            locator.observe<Database>();
            locator.observe<StreamingSharedPreferences>();
            locator.observe<UserStore>();

            return AppState.ready;

        } catch (e) {
            // Return loading state if any values are still loading
            return AppState.loading;
        }
    }),
]);
```

If inside a Flutter app, use the `Observer` widget to observe the `AppState`
and return a placeholder while your dependencies are loading.

```dart
return Observer(
    (context) {
        final appState = locator.observe<AppState>();

        switch(appState) {
            case AppState.ready: return HomeScreen();
            case AppState.loading: return LoadingScreen();
        }
    },
);
```

This way, calling `observe` on your async dependencies will always be
safe. Any async values that aren't crucial to your app's startup can
still be retrievd using `tryObserve()`.