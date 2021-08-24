import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:observable_locator/observable_locator.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('futures', () {
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
      final completer = Completer<String>();

      locator = ObservableLocator([
        singleFuture<String>(() => completer.future),
      ]);

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

      locator = ObservableLocator([
        singleFuture<String>(() => completer.future),
      ]);

      expectObservableValue(
        () => locator.tryObserve<String>(),
        emitsInOrder(<dynamic>[
          isNull,
          equals('done'),
        ]),
      );

      completer.complete('done');
    });
    test('are recomputed on observable change', () async {
      final base = Observable(1);
      final multiplier = Observable(5);
      final continueStream = StreamController<void>.broadcast();

      locator = ObservableLocator([
        singleFuture<int>(() async {
          final baseValue = base.value;
          await continueStream.stream.first;
          return baseValue * multiplier.value;
        }),
      ]);

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
    test('are recomputed even after awaiting', () async {
      final base = Observable(1);
      final multiplier = Observable(5);
      final continueStream = StreamController<void>.broadcast();

      locator = ObservableLocator([
        singleFuture<int>(() async {
          final baseValue = base.value;
          await continueStream.stream.first;
          return baseValue * multiplier.value;
        }),
      ]);

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
    }, skip: 'LIMITATION: Recomputing after awaited not yet supported by MobX');
    test('pendingValue works as expected', () async {
      final observable = Observable(1);
      final awaitStream = StreamController<void>.broadcast();

      locator = ObservableLocator([
        singleFuture<int>(
          () async {
            final value = observable.value;
            await awaitStream.stream.first;
            return value;
          },
          pendingValue: -1,
        ),
      ]);

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
    test('that throw while registering reflect errors', () async {
      locator = ObservableLocator([
        singleFuture<bool>(() => throw FormatException()),
        singleFuture<int>(() async => throw FormatException()),
        singleFuture<String>(() async {
          await Future.microtask(() => null);
          throw FormatException();
        }),
      ]);

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

      locator = ObservableLocator([
        FutureBinder<Disposable>((locator, value, future) {
          final currentDescription = description.value;

          if (value != null && future != null) {
            value.description = currentDescription;
            return future;
          }

          return Future(() => null).then(
            (_) => (value ??= Disposable())..description = description.value,
          );
        }),
      ]);

      // ignore: unawaited_futures
      expectObservableValue<Disposable>(
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
      expect(locator.observe<Disposable>().description, equals('second'));
    });
    test('async values can be used transitively', () {
      locator = ObservableLocator([
        singleFuture<int>(() async {
          await Future<void>(() => null);
          return 100;
        }),
        Binder<String>((locator, _) => locator.observe<int>().toString()),
      ]);

      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
          equals('100'),
        ]),
      );
    });
  });
}
