import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:observable_locator/observable_locator.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('values', () {
    late ObservableLocator locator;
    var isDisposed = false;

    setUp(() {
      isDisposed = false;
    });

    void disposeLocator() {
      if (!isDisposed) {
        isDisposed = true;
        locator.dispose();
      }
    }

    tearDown(() {
      disposeLocator();
    });
    test('work as expected', () {
      locator = ObservableLocator([
        single<int>(() => 100),
      ]);

      expect(locator.observe<int>(), equals(100));
    });

    test('throw if type is not registered', () {
      locator = ObservableLocator();

      expect(
        () => locator.observe<String>(),
        throwsA(isA<LocatorKeyNotFoundException>()),
      );
      expect(locator.tryObserve<String>(), isNull);
    });
    test('throw if registering same type multiple times', () {
      expect(
        () => locator = ObservableLocator([
          single<int>(() => 100),
          single<int>(() => 200),
        ]),
        throwsA(isA<LocatorValueAlreadyRegisteredException>()),
      );

      isDisposed = true; // locator never set
    });
    test('throw if registering dynamic type', () {
      expect(
        () => locator = ObservableLocator([
          single<dynamic>(() => 100),
        ]),
        throwsA(isA<AssertionError>()),
      );

      isDisposed = true; // locator never set
    });

    test('update reactions when observed', () {
      final observable = Observable('first');

      locator = ObservableLocator([
        single<String>(() => observable.value),
      ]);

      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          equals('first'),
          equals('second'),
          equals('third'),
        ]),
      );

      observable.setSingle('second');
      observable.setSingle('third');
    });

    test('transitively update reactions', () {
      final observable = Observable(100);

      locator = ObservableLocator([
        single<int>(() => observable.value),
        bind<String>((locator) => locator.observe<int>().toString()),
      ]);

      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          equals('100'),
          equals('200'),
          equals('300'),
        ]),
      );

      observable.setSingle(200);
      observable.setSingle(300);
    });

    test('can handle errors while registering', () {
      locator = ObservableLocator([
        single<String>(() => throw FormatException()),
      ]);

      expect(
        () => locator.observe<String>(),
        throwsA(isA<FormatException>()),
      );

      expect(
        locator.tryObserve<String>(),
        isNull,
      );
    });

    test('can transitively handle error when type isn\'t registered', () {
      locator = ObservableLocator([
        bind<String>((locator) => locator.observe<double>().toString()),
      ]);

      expect(
        () => locator.observe<String>(),
        throwsA(isA<LocatorKeyNotFoundException>()),
      );

      expect(
        locator.tryObserve<String>(),
        isNull,
      );
    });

    test('can transitively handle errors while registering', () {
      locator = ObservableLocator([
        single<double>(() => throw FormatException()),
        bind<String>((locator) => locator.observe<double>().toString()),
      ]);

      expect(
        () => locator.observe<String>(),
        throwsA(isA<FormatException>()),
      );

      expect(
        locator.tryObserve<String>(),
        isNull,
      );
    });

    test('can switch between errors and values', () {
      final shouldThrow = Observable(false);

      locator = ObservableLocator([
        single<String>(
          () => shouldThrow.value ? throw FormatException() : 'working',
        ),
      ]);

      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          equals('working'),
          emitsError(isA<FormatException>()),
          equals('working'),
        ]),
      );

      shouldThrow.setSingle(true);
      shouldThrow.setSingle(false);
    });
    test('value hierarchy matches behavior of computed', () {
      final x = Observable(10);
      final y = Observable(20);
      final z = Observable(30);

      var doubleCount = 0;
      var stringCount = 0;

      locator = ObservableLocator([
        single<double>(() {
          doubleCount++;
          return x.value.toDouble() + y.value.toDouble();
        }),
        single<int>(() => z.value),
        bind<String>((locator) {
          stringCount++;

          final doubleValue = locator.observe<double>();
          final intValue = locator.observe<int>();
          return (doubleValue + intValue).toString();
        }),
      ]);

      final disposeObserveString = autorun((_) {
        locator.observe<String>();
      });

      expect(locator.observe<String>(), equals('60.0'));
      expect(doubleCount, equals(1));
      expect(stringCount, equals(1));

      runInAction(() {
        // Setting values such that string does not need to compute
        x.value = 20;
        y.value = 10;
      });

      // Should be recomputed as both x and y have changed
      expect(doubleCount, equals(2));

      // Should not change as value is same as before
      expect(stringCount, equals(1));
      expect(locator.observe<String>(), equals('60.0'));

      x.setSingle(30);

      expect(locator.observe<String>(), equals('70.0'));
      expect(doubleCount, equals(3));
      expect(stringCount, equals(2));

      disposeObserveString();
    });

    test('dispose correctly', () {
      final firstDisposable = Disposable();
      final observable = Observable(firstDisposable);

      locator = ObservableLocator([
        single<Disposable>(
          () => observable.value,
          dispose: (disposable) => disposable.dispose(),
        ),
      ]);

      final disposeObserve = autorun((_) => locator.observe<Disposable>());

      expect(firstDisposable.disposeCount, equals(0),
          reason: 'first shouldn\'t be disposed yet');

      final secondDisposable = Disposable();
      observable.setSingle(secondDisposable);

      expect(firstDisposable.disposeCount, equals(1),
          reason: 'first should be disposed');
      expect(secondDisposable.disposeCount, equals(0),
          reason: 'second shouldn\'t be disposed yet');

      disposeObserve();
      disposeLocator();

      expect(firstDisposable.disposeCount, equals(1),
          reason: 'first should still be disposed');
      expect(secondDisposable.disposeCount, equals(1),
          reason: 'second should be disposed');
    });
    test('only disposes if values are different', () {
      final firstDisposable = Disposable('x');
      final observable = Observable(firstDisposable);

      locator = ObservableLocator([
        single<Disposable>(
          () => observable.value,
          equals: (a, b) => a?.name == b?.name,
          dispose: (disposable) => disposable.dispose(),
        ),
      ]);

      final disposeObserve = autorun((_) => locator.observe<Disposable>());

      expect(firstDisposable.disposeCount, equals(0));
      expect(locator.observe<Disposable>(), equals(firstDisposable));

      final secondDisposable = Disposable('x');
      observable.setSingle(secondDisposable);

      // should still be the first disposable
      expect(firstDisposable.disposeCount, equals(0));
      expect(secondDisposable.disposeCount, equals(0));
      expect(locator.observe<Disposable>(), equals(firstDisposable));

      final thirdDisposable = Disposable('y');
      observable.setSingle(thirdDisposable);

      // should be the third disposable; second ignored completely
      expect(firstDisposable.disposeCount, equals(1));
      expect(secondDisposable.disposeCount, equals(0));
      expect(thirdDisposable.disposeCount, equals(0));
      expect(locator.observe<Disposable>(), equals(thirdDisposable));

      disposeObserve();
      disposeLocator();

      expect(firstDisposable.disposeCount, equals(1));
      expect(secondDisposable.disposeCount, equals(0));
      expect(thirdDisposable.disposeCount, equals(1));
    });
    test('use equals to determine whether to update', () {
      final observable = Observable('apple');

      locator = ObservableLocator([
        single<String>(
          () => observable.value,
          equals: (a, b) => a?.codeUnitAt(0) == b?.codeUnitAt(0),
        ),
      ]);

      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          equals('apple'),
          equals('banana'),
          equals('cherry'),
        ]),
      );

      observable.setSingle('avocado');
      observable.setSingle('banana');
      observable.setSingle('blueberry');
      observable.setSingle('cherry');
    });
    test('old values are passed to register callback', () async {
      final description = Observable('first');
      final cancelObservation = Completer<void>();

      locator = ObservableLocator([
        bindValue<Disposable>(
          (locator, value) =>
              (value ??= Disposable())..description = description.value,
          dispose: (disposable) => disposable.dispose(),
        ),
      ]);

      // ignore: unawaited_futures
      expectObservableValue<Disposable>(
        locator.observe,
        emitsInOrder(<dynamic>[
          isDisposableWith(
            description: 'first',
            disposeCount: 0,
          ),
          emitsDone, // old object should be mutated, will not be re-emitted
        ]),
        cancelObservation: cancelObservation.future,
      );

      await pumpEventQueue();
      description.setSingle('second');
      await pumpEventQueue();
      cancelObservation.complete();

      expect(locator.observe<Disposable>().description, equals('second'));
    });
    test('can catch errors', () {
      final shouldThrow = Observable(false);

      locator = ObservableLocator([
        single<int>(
          () => shouldThrow.value ? throw FormatException() : 100,
          catchError: (e) => -1,
        ),
      ]);

      expectObservableValue<int>(
        locator.observe,
        emitsInOrder(<dynamic>[
          equals(100),
          equals(-1),
          equals(100),
        ]),
      );

      shouldThrow.setSingle(true);
      shouldThrow.setSingle(false);
    });
    test('can depend on values that throw errors', () {
      final shouldThrow = Observable(false);

      locator = ObservableLocator([
        single<int>(
          () => shouldThrow.value ? throw FormatException() : 100,
        ),
        bind<String>((locator) => locator.observe<int>().toString()),
      ]);

      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          equals('100'),
          emitsError(isA<FormatException>()),
          equals('100'),
        ]),
      );

      shouldThrow.setSingle(true);
      shouldThrow.setSingle(false);
    });
  });
}
