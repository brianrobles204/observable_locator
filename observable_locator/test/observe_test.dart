import 'dart:async';

import 'package:observable_locator/observable_locator.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('observing values', () {
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
    test('handles nullable types', () {
      locator = ObservableLocator([
        single<String?>(() => 'test'),
        single<int?>(() => null),
      ]);

      expect(
        () => locator.observe<String>(),
        throwsA(isA<LocatorKeyNotFoundException>()),
      );

      expect(locator.observe<String?>(), equals('test'));

      expect(locator.observe<int?>(), isNull);
    });
    test('handles nullable types with dependencies', () async {
      final completer = Completer<String?>();
      final cancelObservation = Completer<void>();
      var count = 0;

      locator = ObservableLocator([
        singleFuture<Box<String?>>(() async {
          final result = await completer.future;
          count++;
          return Box(result);
        }),
        bind<Disposable>(
          (locator) {
            final nameBox = locator.observe<Box<String?>>();
            return Disposable(nameBox.value);
          },
        ),
        bind<String?>(
          (locator) => locator.tryObserve<Disposable>()?.name,
        ),
      ]);

      // ignore: unawaited_futures
      expectObservableValue<String?>(
        () => locator.observe<String?>(),
        emitsInOrder(<dynamic>[
          isNull,
        ]),
        cancelObservation: cancelObservation.future,
      );

      await pumpEventQueue();
      expect(count, equals(0));

      completer.complete(null);
      await pumpEventQueue();
      expect(count, equals(1));

      cancelObservation.complete();
    });
    test('handles unregistered types', () async {
      locator = ObservableLocator();
      final cancelObservation = Completer<void>();

      // ignore: unawaited_futures
      expectObservableValue<String>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorKeyNotFoundException>()),
          emitsDone,
        ]),
        cancelObservation: cancelObservation.future,
      );

      // ignore: unawaited_futures
      expectObservableValue(
        () => locator.tryObserve<String>(),
        emitsInOrder(<dynamic>[
          isNull,
          emitsDone,
        ]),
        cancelObservation: cancelObservation.future,
      );

      cancelObservation.complete();
    });
    test('throws if observing dynamic type', () async {
      locator = ObservableLocator();
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
}
