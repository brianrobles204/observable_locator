import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:observable_locator/observable_locator.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('children', () {
    late ObservableLocator parent;
    ReactionDisposer? disposeAutoWatch;
    var isDisposed = false;
    var count = 0;

    _Counter createCounter() => _Counter(count++);

    setUp(() {
      isDisposed = false;
      count = 0;
      disposeAutoWatch = null;
    });

    void disposeLocator() {
      if (!isDisposed) {
        isDisposed = true;
        parent.dispose();
      }
    }

    void autoObserve<T>({required ObservableLocator of}) {
      assert(disposeAutoWatch == null);
      disposeAutoWatch = autorun((_) {
        try {
          of.observe<T>();
        } catch (e) {
          // NO OP
        }
      });
    }

    tearDown(() {
      disposeLocator();
      disposeAutoWatch?.call();
      disposeAutoWatch = null;
    });

    group('can access parent values', () {
      test('that already exist', () {
        parent = ObservableLocator([
          single<_Counter>(() => createCounter()),
        ]);

        final child = parent.createChild([]);
        expect(child.parent, equals(parent));

        autoObserve<_Counter>(of: parent); // read parent first

        expect(parent.observe<_Counter>().value, equals(0));
        expect(child.observe<_Counter>().value, equals(0));
        expect(count, equals(1));
      });
      test('without overriding the value', () {
        parent = ObservableLocator([
          single<_Counter>(() => createCounter()),
        ]);

        final child = parent.createChild([]);
        expect(child.parent, equals(parent));

        autoObserve<_Counter>(of: child); // read child first

        expect(child.observe<_Counter>().value, equals(0));
        expect(parent.observe<_Counter>().value, equals(0));
        expect(count, equals(1));
      });
      test('that change due to observables', () {
        final atom = Atom();

        parent = ObservableLocator([
          single<_Counter>(() {
            atom.reportRead();
            return createCounter();
          }),
        ]);

        final child = parent.createChild([]);

        expectAllObservableValues(
          observeValuesOf<_Counter>([child, parent]),
          emitsInOrder(<dynamic>[
            emitsCounter(value: 0),
            emitsCounter(value: 1),
          ]),
        );

        expect(count, equals(1));
        atom.reportChanged();
        expect(count, equals(2));
      });
      test('that change due to state updates', () async {
        parent = ObservableLocator([
          singleFuture<_Counter>(() async {
            await Future.microtask(() => null);
            return createCounter();
          }),
        ]);

        final child = parent.createChild([]);

        expectAllObservableValues(
          observeValuesOf<_Counter>([child, parent]),
          emitsInOrder(<dynamic>[
            emitsError(isA<LocatorValueMissingException>()),
            emitsCounter(value: 0),
          ]),
        );

        expect(count, equals(0));
        await pumpEventQueue();
        expect(count, equals(1));
      });
      test('with old values passed to bind callback', () async {
        final description = Observable('first');
        final cancelObservation = Completer<void>();

        parent = ObservableLocator([
          Binder<Disposable>(
            (locator, value) =>
                (value ??= Disposable())..description = description.value,
            dispose: (disposable) => disposable.dispose(),
          ),
        ]);

        final child = parent.createChild([]);

        // ignore: unawaited_futures
        expectObservableValue<Disposable>(
          child.observe,
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

        expect(child.observe<Disposable>().description, equals('second'));
      });
      test('that have errors', () {
        final shouldThrow = Observable(true);

        parent = ObservableLocator([
          single<_Counter>(
            () => shouldThrow.value ? throw FormatException() : createCounter(),
          ),
        ]);

        final child = parent.createChild([]);

        expectAllObservableValues(
          observeValuesOf<_Counter>([child, parent]),
          emitsInOrder(<dynamic>[
            emitsError(isFormatException),
            emitsCounter(value: 0),
          ]),
        );

        expect(count, equals(0));
        shouldThrow.setSingle(false);
        expect(count, equals(1));
      });
    });
    test('can depend on parent values', () {
      parent = ObservableLocator([
        single<Box>(() => Box('value')),
      ]);

      final child = parent.createChild([
        Binder<String>((locator, _) => locator.observe<Box>().value),
      ]);

      expect(child.observe<String>(), equals('value'));
    });
    test('can depend on parent values that change due to observables', () {
      var parentCount = 0, childCount = 0;
      final observable = Observable(100);

      parent = ObservableLocator([
        single<int>(() {
          parentCount++;
          return observable.value;
        }),
      ]);

      final child = parent.createChild([
        Binder<String>((locator, __) {
          childCount++;
          return locator.observe<int>().toString();
        }),
      ]);

      expectObservableValue<String>(
        child.observe,
        emitsInOrder(<dynamic>[
          equals('100'),
          equals('200'),
          equals('300'),
        ]),
      );

      expect(parentCount, equals(1));
      expect(childCount, equals(1));

      observable.setSingle(200);
      expect(parentCount, equals(2));
      expect(childCount, equals(2));

      observable.setSingle(300);
      expect(parentCount, equals(3));
      expect(childCount, equals(3));
    });
    test('can override values of the parent', () {
      parent = ObservableLocator([
        single<int>(() => 100),
      ]);

      final child = parent.createChild([
        single<int>(() => 200),
      ]);

      expect(child.observe<int>(), equals(200));
      expect(parent.observe<int>(), equals(100));
    });
    test('values are scoped to each child', () {
      parent = ObservableLocator([]);

      final first = parent.createChild([
        single<String>(() => 'first'),
      ]);

      final second = parent.createChild([
        single<String>(() => 'second'),
      ]);

      expect(first.observe<String>(), equals('first'));
      expect(second.observe<String>(), equals('second'));
    });
    test('can override intermediate values', () {
      parent = ObservableLocator([
        single<int>(() => 1),
        Binder<String>((locator, _) => locator.observe<int>().toString()),
      ]);

      final child = parent.createChild([
        single<int>(() => 2),
      ]);

      expect(child.observe<String>(), equals('2'));
    });
    // test('can override changing intermediate values', () {});
    test('disposing works', () {
      parent = ObservableLocator([]);

      final disposable = Disposable();
      final child = parent.createChild([
        single<Disposable>(
          () => disposable,
          dispose: (value) => value.dispose(),
        ),
      ]);

      expect(child.observe<Disposable>().disposeCount, equals(0));

      child.dispose();
      expect(disposable.disposeCount, equals(1));
    });
    test('disposing a parent will also dispose all children', () {
      parent = ObservableLocator([]);

      final xDisposable = Disposable();
      final x = parent.createChild([
        single<Disposable>(
          () => xDisposable,
          dispose: (value) => value.dispose(),
        ),
      ]);

      final x1Disposable = Disposable();
      final x1 = x.createChild([
        single<Disposable>(
          () => x1Disposable,
          dispose: (value) => value.dispose(),
        ),
      ]);

      final x11Disposable = Disposable();
      final x11 = x1.createChild([
        single<Disposable>(
          () => x11Disposable,
          dispose: (value) => value.dispose(),
        ),
      ]);

      final x2Disposable = Disposable();
      final x2 = x.createChild([
        single<Disposable>(
          () => x2Disposable,
          dispose: (value) => value.dispose(),
        ),
      ]);

      expect(x.observe<Disposable>().disposeCount, equals(0));
      expect(x1.observe<Disposable>().disposeCount, equals(0));
      expect(x11.observe<Disposable>().disposeCount, equals(0));
      expect(x2.observe<Disposable>().disposeCount, equals(0));
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

class _Counter {
  _Counter(this.value);

  final int value;
}

Matcher emitsCounter({required int value}) => emits(
      predicate<_Counter>((counter) => counter.value == value),
    );
