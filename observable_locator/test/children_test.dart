import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:observable_locator/observable_locator.dart';
import 'package:test/test.dart';

import 'children_test_helper.dart';
import 'utils.dart';

void main() {
  group('children', () {
    late ObservableLocator parent;
    var isDisposed = false;
    var count = 0;

    var helper = ChildrenTestHelper();

    _Counter createCounter() => _Counter(count++);

    setUp(() {
      isDisposed = false;
      count = 0;

      helper.reset();
    });

    void disposeLocator() {
      if (!isDisposed) {
        isDisposed = true;
        parent.dispose();
      }
    }

    tearDown(() {
      disposeLocator();
      helper.dispose();
    });

    group('can access parent values', () {
      test('that already exist', () {
        parent = ObservableLocator(); // TODO remove

        helper
          ..addParentHeadValue()
          ..initLocators();

        expect(helper.parentHead, isHeadWith(count: 0)); // read parent first
        expect(helper.childHead, isHeadWith(count: 0));
        expect(helper.totalCount, equals(1));
      });
      test('without overriding the value', () {
        parent = ObservableLocator();

        helper
          ..addParentHeadValue()
          ..initLocators();

        expect(helper.childHead, isHeadWith(count: 0)); // read child first
        expect(helper.parentHead, isHeadWith(count: 0));
        expect(helper.totalCount, equals(1));
      });
      test('that change due to observables', () async {
        parent = ObservableLocator();

        final observable = helper.withObservableParentHead('x');

        helper
          ..addParentHeadValue()
          ..initLocators();

        expectAllObservableValues(
          helper.allLocatorsObserve<Head>(),
          emitsInOrder(<dynamic>[
            isHeadWith(obsValue: 'x'),
            isHeadWith(obsValue: 'y'),
          ]),
        );

        await pumpEventQueue();

        expect(helper.totalCount, equals(1));
        observable.setSingle('y');
        expect(helper.totalCount, equals(2));
      });
      test('that change due to async updates', () async {
        parent = ObservableLocator();

        final completer = helper.addParentHeadFuture();
        helper.initLocators();

        // ignore: unawaited_futures
        expectAllObservableValues(
          helper.allLocatorsObserve<Head>(),
          emitsInOrder(<dynamic>[
            emitsError(isA<LocatorValueMissingException>()),
            isHeadWith(value: 'done', count: 0),
          ]),
        );

        expect(helper.totalCount, equals(0));

        completer.complete('done');
        await pumpEventQueue();

        expect(helper.totalCount, equals(1));
      });
      test('with old values passed to bind callback', () async {
        parent = ObservableLocator();
        final cancelObservation = Completer<void>();

        helper
          ..addParentHeadValue()
          ..initLocators();

        final mutObservable = helper.withMutableParentHead('first');

        // ignore: unawaited_futures
        expectObservableValue(
          () => helper.childHead,
          emitsInOrder(<dynamic>[
            isHeadWith(
              mutValue: 'first',
              disposeCount: 0,
            ),
            emitsDone, // old object should be mutated, will not be re-emitted
          ]),
          cancelObservation: cancelObservation.future,
        );

        await pumpEventQueue();
        mutObservable.setSingle('second');
        await pumpEventQueue();
        cancelObservation.complete();

        expect(helper.childHead, isHeadWith(mutValue: 'second'));
      });
      test('that have errors', () {
        parent = ObservableLocator();

        final throwable = helper.withThrowableParentHead(FormatException());

        helper
          ..addParentHeadValue(value: 'success')
          ..initLocators();

        expectAllObservableValues(
          helper.allLocatorsObserve<Head>(),
          emitsInOrder(<dynamic>[
            emitsError(isFormatException),
            isHeadWith(value: 'success', count: 0),
          ]),
        );

        expect(helper.totalCount, equals(0));
        throwable.setSingle(null);
        expect(helper.totalCount, equals(1));
      });
    });
    group('can override parent values', () {
      test('with minimal recomputation', () {
        parent = ObservableLocator([
          single<_Counter>(() => createCounter()),
        ]);

        final child = parent.createChild([
          single<_Counter>(() => createCounter()),
        ]);

        expect(count, equals(0));
        expect(child.observe<_Counter>().value, equals(0));
        expect(count, equals(1));
        expect(parent.observe<_Counter>().value, equals(1));
        expect(count, equals(2));

        expect(parent.observe<_Counter>().value, equals(1));
        expect(count, equals(2));
        expect(child.observe<_Counter>().value, equals(0));
        expect(count, equals(2));
      });
      test('while changing due to observables', () {
        var parentCount = 0, childCount = 0;
        final parentObs = Observable('a'), childObs = Observable('x');

        parent = ObservableLocator([
          single<String>(() {
            parentCount++;
            return parentObs.value;
          }),
        ]);

        final child = parent.createChild([
          single<String>(() {
            childCount++;
            return childObs.value;
          }),
        ]);

        expect(parentCount, equals(0));
        expect(childCount, equals(0));

        expectObservableValue<String>(
          child.observe,
          emitsInOrder(<dynamic>[
            emits('x'),
            emits('y'),
            emits('z'),
          ]),
        );

        expect(parentCount, equals(0));
        expect(childCount, equals(1));

        expectObservableValue<String>(
          parent.observe,
          emitsInOrder(<dynamic>[
            emits('a'),
            emits('b'),
            emits('c'),
          ]),
        );

        expect(parentCount, equals(1));
        expect(childCount, equals(1));

        // Update child first
        childObs.setSingle('y');
        expect(parentCount, equals(1));
        expect(childCount, equals(2));

        parentObs.setSingle('b');
        expect(parentCount, equals(2));
        expect(childCount, equals(2));

        // Update parent first
        parentObs.setSingle('c');
        expect(parentCount, equals(3));
        expect(childCount, equals(2));

        childObs.setSingle('z');
        expect(parentCount, equals(3));
        expect(childCount, equals(3));
      });
      // test('that change due to async updates', () {
      //   //
      // });
      // test('with old values passed to bind callback', () {
      //   //
      // });
      // test('that have errors', () {
      //   //
      // });
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
    test('values are scoped to each child', () {
      parent = ObservableLocator();

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
      parent = ObservableLocator();

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
      parent = ObservableLocator();

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
