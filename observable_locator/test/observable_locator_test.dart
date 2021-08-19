import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:observable_locator/observable_locator.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  late WritableObservableLocator locator;

  setUp(() {
    locator = ObservableLocator.writable();
  });

  tearDown(() {
    locator.dispose();
  });

  group('registering computed values', () {
    test('works as expected', () {
      locator.register<int>((_) => 100);

      expect(locator.observe<int>(), equals(100));
    });

    test('throws if type is not registered', () {
      expect(
        () => locator.observe<String>(),
        throwsA(isA<LocatorTypeNotRegisteredException>()),
      );
      expect(locator.tryObserve<String>(), isNull);
    });
    test('throws if registering same type multiple times', () {
      locator.register<int>((_) => 100);
      expect(
        () => locator.register<int>((_) => 200),
        throwsA(isA<LocatorValueAlreadyRegisteredException>()),
      );
    });
    test('throws if registering dynamic type', () {
      expect(
        () => locator.register<dynamic>((dynamic _) => 100),
        throwsA(isA<AssertionError>()),
      );
    });

    test('updates reactions when observed', () {
      final observable = Observable('first');

      locator.register((_) => observable.value);

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

    test('transitively updates reactions', () {
      final observable = Observable(100);

      locator.register<int>((_) => observable.value);
      locator.register<String>((_) => locator.observe<int>().toString());

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

    test('handles errors while registering', () {
      locator.register<String>((_) => throw FormatException());

      expect(
        () => locator.observe<String>(),
        throwsA(isA<FormatException>()),
      );

      expect(
        locator.tryObserve<String>(),
        isNull,
      );
    });

    test('transitively handles error when type isn\'t registered', () {
      locator.register<String>((_) => locator.observe<double>().toString());

      expect(
        () => locator.observe<String>(),
        throwsA(isA<LocatorTypeNotRegisteredException>()),
      );

      expect(
        locator.tryObserve<String>(),
        isNull,
      );
    });

    test('transitively handles errors while registering', () {
      locator.register<double>((_) => throw FormatException());
      locator.register<String>((_) => locator.observe<double>().toString());

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

      locator.register<String>(
        (_) => shouldThrow.value ? throw FormatException() : 'working',
      );

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

      locator.register<double>((_) {
        doubleCount++;
        return x.value.toDouble() + y.value.toDouble();
      });

      locator.register<int>((_) => z.value);

      locator.register<String>((_) {
        stringCount++;

        final doubleValue = locator.observe<double>();
        final intValue = locator.observe<int>();
        return (doubleValue + intValue).toString();
      });

      final disposeObserveString = autorun((_) {
        locator.observe<String>();
      });

      expect(locator.observe<String>(), equals('60.0'));
      expect(doubleCount, equals(1));
      expect(stringCount, equals(1));

      Action(() {
        // Setting values such that string does not need to compute
        x.value = 20;
        y.value = 10;
      })();

      // Should be recomputed as both x and y have changed
      expect(doubleCount, equals(2));

      // Should not change as value is same as before
      expect(stringCount, equals(1));

      x.setSingle(30);

      expect(doubleCount, equals(3));
      expect(stringCount, equals(2));

      disposeObserveString();
    });

    test('disposes correctly', () {
      final testLocator = ObservableLocator.writable();

      final firstDisposable = _Disposable();
      final observable = Observable(firstDisposable);

      testLocator.register<_Disposable>(
        (_) => observable.value,
        dispose: (disposable) => disposable.dispose(),
      );

      final disposeObserve = autorun((_) => testLocator.observe<_Disposable>());

      expect(firstDisposable.disposeCount, equals(0),
          reason: 'first shouldn\'t be disposed yet');

      final secondDisposable = _Disposable();
      observable.setSingle(secondDisposable);

      expect(firstDisposable.disposeCount, equals(1),
          reason: 'first should be disposed');
      expect(secondDisposable.disposeCount, equals(0),
          reason: 'second shouldn\'t be disposed yet');

      disposeObserve();
      testLocator.dispose();

      expect(firstDisposable.disposeCount, equals(1),
          reason: 'first should still be disposed');
      expect(secondDisposable.disposeCount, equals(1),
          reason: 'second should be disposed');
    });
    test('only disposes if values are different', () {
      final testLocator = ObservableLocator.writable();

      final firstDisposable = _Disposable('x');
      final observable = Observable(firstDisposable);

      testLocator.register<_Disposable>(
        (_) => observable.value,
        equals: (a, b) => a?.name == b?.name,
        dispose: (disposable) => disposable.dispose(),
      );

      final disposeObserve = autorun((_) => testLocator.observe<_Disposable>());

      expect(firstDisposable.disposeCount, equals(0));
      expect(testLocator.observe<_Disposable>(), equals(firstDisposable));

      final secondDisposable = _Disposable('x');
      observable.setSingle(secondDisposable);

      // should still be the first disposable
      expect(firstDisposable.disposeCount, equals(0));
      expect(secondDisposable.disposeCount, equals(0));
      expect(testLocator.observe<_Disposable>(), equals(firstDisposable));

      final thirdDisposable = _Disposable('y');
      observable.setSingle(thirdDisposable);

      // should be the third disposable; second ignored completely
      expect(firstDisposable.disposeCount, equals(1));
      expect(secondDisposable.disposeCount, equals(0));
      expect(thirdDisposable.disposeCount, equals(0));
      expect(testLocator.observe<_Disposable>(), equals(thirdDisposable));

      disposeObserve();
      testLocator.dispose();

      expect(firstDisposable.disposeCount, equals(1));
      expect(secondDisposable.disposeCount, equals(0));
      expect(thirdDisposable.disposeCount, equals(1));
    });
    test('old values are passed to register callback', () async {
      final description = Observable('first');
      final cancelObservation = Completer<void>();
      locator.register<_Disposable>(
        (value) => (value ??= _Disposable())..description = description.value,
        dispose: (disposable) => disposable.dispose(),
      );

      // ignore: unawaited_futures
      expectObservableValue<_Disposable>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsDisposableWith(
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

      expect(locator.observe<_Disposable>().description, equals('second'));
    });
    test('catches errors', () {
      final shouldThrow = Observable(false);
      locator.register<int>(
        (_) => shouldThrow.value ? throw FormatException() : 100,
        catchError: (e) => -1,
      );

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
  });
  group('observing values', () {
    test('handles nullable types', () {
      locator.register<String?>((_) => 'test');
      locator.register<int?>((_) => null);

      expect(
        () => locator.observe<String>(),
        throwsA(isA<LocatorTypeNotRegisteredException>()),
      );

      expect(locator.observe<String?>(), equals('test'));

      expect(locator.observe<int?>(), isNull);
    });
    test('handles nullable types with dependencies', () async {
      final completer = Completer<String?>();
      final cancelObservation = Completer<void>();
      var count = 0;

      locator.registerFuture<_Box<String?>>((_, __) async {
        final result = await completer.future;
        count++;
        return _Box(result);
      });
      locator.register<_Disposable>(
        (_) {
          final nameBox = locator.observe<_Box<String?>>();
          return _Disposable(nameBox.value);
        },
      );
      locator.register<String?>((_) => locator.tryObserve<_Disposable>()?.name);

      // ignore: unawaited_futures
      expectObservableValue<String?>(
        () => locator.observe<String?>(),
        emitsInOrder(<dynamic>[
          isNull,
        ]),
        cancelObservation: cancelObservation.future,
        debugPrint: true,
      );

      await pumpEventQueue();
      expect(count, equals(0));

      completer.complete(null);
      await pumpEventQueue();
      expect(count, equals(1));

      cancelObservation.complete();
    });
    test('handles unregistered types', () async {
      final cancelObservation = Completer<void>();

      // ignore: unawaited_futures
      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorTypeNotRegisteredException>()),
          emitsDone,
        ]),
        cancelObservation: cancelObservation.future,
      );

      final tryObserve = expectObservableValue(
        () => locator.tryObserve<String>(),
        emitsInOrder(<dynamic>[
          isNull,
          equals('working'),
        ]),
      );

      locator.register<String>((_) => 'working');

      await tryObserve;
      cancelObservation.complete();
    });
    test('throws if observing dynamic type', () async {
      expect(
        () => locator.observe<dynamic>(),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => locator.tryObserve<dynamic>(),
        throwsA(isA<AssertionError>()),
      );
    });
  });
  group('registering futures', () {
    test('works as expected', () {
      final completer = Completer<String>();
      locator.registerFuture<String>((_, __) => completer.future);

      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          equals('done'),
        ]),
      );

      completer.complete('done');
    });
    test('tryObserve works as expected', () {
      final completer = Completer<String>();
      locator.registerFuture<String>((_, __) => completer.future);

      expectObservableValue(
        () => locator.tryObserve<String>(),
        emitsInOrder(<dynamic>[
          isNull,
          equals('done'),
        ]),
      );

      completer.complete('done');
    });
    test('futures are recomputed on observable change', () async {
      final base = Observable(1);
      final multiplier = Observable(5);
      final continueStream = StreamController<void>.broadcast();

      locator.registerFuture<int>((_, __) async {
        final baseValue = base.value;
        await continueStream.stream.first;
        return baseValue * multiplier.value;
      });

      // ignore: unawaited_futures
      expectObservableValue<int>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          equals(5),
          emitsError(isA<LocatorValueMissingException>()),
          equals(10),
          emitsError(isA<LocatorValueMissingException>()),
          equals(12),
        ]),
      );

      continueStream.add(null);
      await pumpEventQueue();

      base.setSingle(2);
      continueStream.add(null);
      await pumpEventQueue();

      multiplier.setSingle(6);
      base.setSingle(3);
      await pumpEventQueue(); // should not update, still awaiting

      multiplier.setSingle(4);
      continueStream.add(null);
      await pumpEventQueue();
    });
    test('futures are recomputed even after awaiting', () async {
      final base = Observable(1);
      final multiplier = Observable(5);
      final continueStream = StreamController<void>.broadcast();

      locator.registerFuture<int>((_, __) async {
        final baseValue = base.value;
        await continueStream.stream.first;
        return baseValue * multiplier.value;
      });

      // ignore: unawaited_futures
      expectObservableValue<int>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          equals(5),
          emitsError(isA<LocatorValueMissingException>()),
          equals(10),
        ]),
      );

      continueStream.add(null);
      await pumpEventQueue();

      multiplier.setSingle(10); // after await
      continueStream.add(null);
      await pumpEventQueue();
    }, skip: 'LIMITATION: Recomputing after awaited not yet supported');
    test('pendingValue works as expected', () async {
      final observable = Observable(1);
      final awaitStream = StreamController<void>.broadcast();

      locator.registerFuture<int>(
        (_, __) async {
          final value = observable.value;
          await awaitStream.stream.first;
          return value;
        },
        pendingValue: -1,
      );

      // ignore: unawaited_futures
      expectObservableValue<int>(
        locator.observe,
        emitsInOrder(<dynamic>[
          equals(-1),
          equals(1),
          equals(-1),
          equals(2),
        ]),
      );

      awaitStream.add(null);
      await pumpEventQueue();

      observable.setSingle(2);
      awaitStream.add(null);
      await pumpEventQueue();
    });
    test('errors while registering futures are reflected', () async {
      locator.registerFuture<bool>((_, __) => throw FormatException());
      locator.registerFuture<int>((_, __) async => throw FormatException());
      locator.registerFuture<String>((_, __) async {
        await Future.microtask(() => null);
        throw FormatException();
      });

      // ignore: unawaited_futures
      expectObservableValue<bool>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<FormatException>()),
        ]),
      );

      // ignore: unawaited_futures
      expectObservableValue<int>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          emitsError(isA<FormatException>()),
        ]),
      );

      // ignore: unawaited_futures
      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          emitsError(isA<FormatException>()),
        ]),
      );

      await pumpEventQueue();
    });
    test('old values and futures are passed to register callback', () async {
      final description = Observable('first');
      final cancelObservation = Completer<void>();

      locator.registerFuture<_Disposable>((value, future) {
        final currentDescription = description.value;

        if (value != null && future != null) {
          value.description = currentDescription;
          return future;
        }

        return Future(() => null).then(
          (_) => (value ??= _Disposable())..description = description.value,
        );
      });

      // ignore: unawaited_futures
      expectObservableValue<_Disposable>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          emitsDisposableWith(
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
      expect(locator.observe<_Disposable>().description, equals('second'));
    });
    test('async values can be used transitively', () {
      locator.registerFuture<int>((_, __) async {
        await Future<void>(() => null);
        return 100;
      });
      locator.register<String>((_) => locator.observe<int>().toString());

      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          equals('100'),
        ]),
      );
    });
  });
  group('registering streams', () {
    test('works as expected', () {
      final controller = StreamController<String>();
      locator.registerStream<String>((_, __) => controller.stream);

      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          equals('first'),
          equals('second'),
        ]),
      );

      controller.add('first');
      controller.add('second');
    });
    test('tryObserve works as expected', () {
      final controller = StreamController<String>();
      locator.registerStream<String>((_, __) => controller.stream);

      expectObservableValue(
        () => locator.tryObserve<String>(),
        emitsInOrder(<dynamic>[
          isNull,
          equals('first'),
          equals('second'),
        ]),
      );

      controller.add('first');
      controller.add('second');
    });
    test('pending values work as expected', () async {
      final observable = Observable(0);
      final controller = StreamController<String>.broadcast();
      final cancelObservation = Completer<void>();
      locator.registerStream<String>(
        (_, __) {
          observable.value;
          return controller.stream;
        },
        pendingValue: 'empty',
      );

      // ignore: unawaited_futures
      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          equals('empty'),
          equals('first'),
          equals('second'),
          equals('empty'),
          equals('third'),
          equals('fourth'),
          emitsDone,
        ]),
        cancelObservation: cancelObservation.future,
      );

      controller.add('first');
      controller.add('second');

      await pumpEventQueue();
      observable.setSingle(1);
      controller.add('third');
      controller.add('fourth');

      await pumpEventQueue();
      cancelObservation.complete();
    });
    test('pending values in a subject work as expected', () async {
      final observable = Observable(0);
      final subject = BehaviorSubject.seeded('empty');
      final cancelObservation = Completer<void>();
      locator.registerStream((_, __) {
        observable.value;
        return subject.stream;
      });

      // ignore: unawaited_futures
      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          equals('empty'),
          equals('first'),
          equals('second'),
          emitsError(isA<LocatorValueMissingException>()),
          equals('second'),
          emitsDone,
        ]),
        cancelObservation: cancelObservation.future,
      );

      await pumpEventQueue();
      subject.add('first');
      subject.add('second');

      await pumpEventQueue();
      observable.setSingle(1);
      cancelObservation.complete();
    });
    test('can register ObservableStreams', () {
      final stringController = StreamController<String>();
      final stringStream = stringController.stream.asObservable();

      final intController = StreamController<int>();
      final intStream = intController.stream.asObservable(initialValue: 0);

      locator.registerStream((_, __) => stringStream);
      locator.registerStream((_, __) => intStream);

      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          equals('first'),
          equals('second'),
        ]),
      );

      stringController.add('first');
      stringController.add('second');

      expectObservableValue<int>(
        locator.observe,
        emitsInOrder(<dynamic>[
          equals(0), // no error if inital value is provided
          equals(1),
          equals(2),
        ]),
      );

      intController.add(1);
      intController.add(2);
    });
    test('streams are recomputed on observable change', () async {
      final multiplier = Observable(2);
      final controller = StreamController<int>.broadcast();

      locator.registerStream<int>(
        (_, __) {
          final value = multiplier.value;
          return controller.stream.map((event) => event * value);
        },
      );

      // ignore: unawaited_futures
      expectObservableValue<int>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          equals(2),
          equals(4),
          emitsError(isA<LocatorValueMissingException>()),
          equals(30),
        ]),
      );

      controller.add(1);
      controller.add(2);

      await pumpEventQueue();
      multiplier.setSingle(10);
      controller.add(3);
    });
    test('errors while registering futures are reflected', () async {
      locator.registerStream<bool>((_, __) => throw FormatException());
      locator.registerStream<int>((_, __) async* {
        throw FormatException();
      });
      locator.registerStream<String>((_, __) async* {
        await Future.microtask(() => null);
        throw FormatException();
      });

      // ignore: unawaited_futures
      expectObservableValue<bool>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<FormatException>()),
        ]),
      );

      // ignore: unawaited_futures
      expectObservableValue<int>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          emitsError(isA<FormatException>()),
        ]),
      );

      // ignore: unawaited_futures
      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          emitsError(isA<FormatException>()),
        ]),
      );

      await pumpEventQueue();
    });
    test('old values and streams are passed to register callback', () async {
      final description = Observable('first');
      final cancelObservation = Completer<void>();

      locator.registerStream<_Disposable>((value, stream) {
        final currentDescription = description.value;

        if (value != null && stream != null) {
          value.description = currentDescription;
          return stream;
        }

        return Stream.value(
          (value ??= _Disposable())..description = description.value,
        );
      });

      // ignore: unawaited_futures
      expectObservableValue<_Disposable>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          emitsDisposableWith(
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
      expect(locator.observe<_Disposable>().description, equals('second'));
    });
  });
  group('children', () {
    test('can access parent registered values', () {
      locator.register<String>((_) => 'value');

      final child = locator.createChild();
      expect(child.parent, equals(locator));
      expect(child.observe<String>(), equals('value'));
    });
    test('can depend on parent values', () {
      locator.register<int>((_) => 100);

      final child = locator.createChild();
      child.register<String>((_) => child.observe<int>().toString());
      expect(child.observe<String>(), equals('100'));
    });
    test('can override values of the parent', () {
      locator.register<int>((_) => 100);

      final child = locator.createChild();
      child.register<int>((_) => 200);

      expect(child.observe<int>(), equals(200));
      expect(locator.observe<int>(), equals(100));
    });
    test('values are scoped to each child', () {
      final first = locator.createChild();
      first.register<String>((_) => 'first');

      final second = locator.createChild();
      second.register<String>((_) => 'second');

      expect(first.observe<String>(), equals('first'));
      expect(second.observe<String>(), equals('second'));
    });
    test('disposing works', () {
      final child = locator.createChild();
      final disposable = _Disposable();

      child.register<_Disposable>(
        (_) => disposable,
        dispose: (value) => value.dispose(),
      );
      expect(child.observe<_Disposable>().disposeCount, equals(0));

      child.dispose();
      expect(disposable.disposeCount, equals(1));
    });
    test('disposing a parent will also dispose all children', () {
      final x = locator.createChild();
      final xDisposable = _Disposable();
      x.register<_Disposable>(
        (_) => xDisposable,
        dispose: (value) => value.dispose(),
      );

      final x1 = x.createChild();
      final x1Disposable = _Disposable();
      x1.register<_Disposable>(
        (_) => x1Disposable,
        dispose: (value) => value.dispose(),
      );

      final x11 = x1.createChild();
      final x11Disposable = _Disposable();
      x11.register<_Disposable>(
        (_) => x11Disposable,
        dispose: (value) => value.dispose(),
      );

      final x2 = x.createChild();
      final x2Disposable = _Disposable();
      x2.register<_Disposable>(
        (_) => x2Disposable,
        dispose: (value) => value.dispose(),
      );

      expect(x.observe<_Disposable>().disposeCount, equals(0));
      expect(x1.observe<_Disposable>().disposeCount, equals(0));
      expect(x11.observe<_Disposable>().disposeCount, equals(0));
      expect(x2.observe<_Disposable>().disposeCount, equals(0));
      expect(x.children.length, equals(2));

      x.dispose();

      expect(xDisposable.disposeCount, equals(1));
      expect(x1Disposable.disposeCount, equals(1));
      expect(x11Disposable.disposeCount, equals(1));
      expect(x2Disposable.disposeCount, equals(1));
      expect(x.children.length, equals(0));
    });
  });
}

extension _ObservableExtensions<T> on Observable<T> {
  void setSingle(T value) => Action(() => this.value = value).call();
}

class _Disposable {
  _Disposable([this.name]);

  final String? name;
  String? description;

  var disposeCount = 0;

  void dispose() => disposeCount++;

  @override
  String toString() => '_Disposable { '
      'name: $name, '
      'description: $description, '
      'disposeCount: $disposeCount'
      '}';
}

class _Box<T> {
  _Box(this.value);

  final T value;
}

Matcher emitsDisposableWith({
  String? name,
  String? description,
  int? disposeCount,
}) =>
    emits(predicate<_Disposable>(
      (d) {
        final nameIsValid = name == null || d.name == name;
        final descriptionIsValid =
            description == null || d.description == description;
        final countIsValid =
            disposeCount != null || d.disposeCount == disposeCount;

        return nameIsValid && descriptionIsValid && countIsValid;
      },
      [
        if (name != null) 'has name of $name',
        if (description != null) 'has description of $description',
        if (disposeCount != null) 'has disposeCount of $disposeCount',
      ].join(', '),
    ));
