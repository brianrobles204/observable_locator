import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:observable_locator/observable_locator.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('streams', () {
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
      final controller = StreamController<String>();

      locator = ObservableLocator([
        singleStream<String>(() => controller.stream),
      ]);

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

      locator = ObservableLocator([
        singleStream<String>(() => controller.stream),
      ]);

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

      locator = ObservableLocator([
        singleStream<String>(
          () {
            observable.value;
            return controller.stream;
          },
          pendingValue: 'empty',
        ),
      ]);

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

      locator = ObservableLocator([
        singleStream<String>(() {
          observable.value;
          return subject.stream;
        }),
      ]);

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

      locator = ObservableLocator([
        singleStream<String>(() => stringStream),
        singleStream<int>(() => intStream),
      ]);

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
    test('are recomputed on observable change', () async {
      final multiplier = Observable(2);
      final controller = StreamController<int>.broadcast();

      locator = ObservableLocator([
        singleStream<int>(
          () {
            final value = multiplier.value;
            return controller.stream.map((event) => event * value);
          },
        ),
      ]);

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
    test('that throw while registering reflect errors', () async {
      locator = ObservableLocator([
        singleStream<bool>(() => throw FormatException()),
        singleStream<int>(() async* {
          throw FormatException();
        }),
        singleStream<String>(() async* {
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
    test('old values and streams are passed to register callback', () async {
      final description = Observable('first');
      final cancelObservation = Completer<void>();

      locator = ObservableLocator([
        StreamBinder<Disposable>((locator, value, stream) {
          final currentDescription = description.value;

          if (value != null && stream != null) {
            value.description = currentDescription;
            return stream;
          }

          return Stream.value(
            (value ??= Disposable())..description = description.value,
          );
        }),
      ]);

      // ignore: unawaited_futures
      expectObservableValue<Disposable>(
        locator.observe,
        emitsInOrder(<dynamic>[
          emitsError(isA<LocatorValueMissingException>()),
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
  });
}
