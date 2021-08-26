import 'dart:async';

import 'package:observable_locator/observable_locator.dart';
import 'package:test/test.dart';

import 'children_test_helper.dart';
import 'utils.dart';

void main() {
  group('children', () {
    var helper = ChildrenTestHelper();

    setUp(() {
      helper.reset();
    });

    tearDown(() {
      helper.dispose();
    });

    group('basic tests', () {
      late ObservableLocator parent;
      setUp(() => parent = ObservableLocator());
      tearDown(() => parent.dispose());

      test('parents and children are linked', () {
        final first = parent.createChild();
        final second = parent.createChild();

        expect(first.parent, equals(parent));
        expect(second.parent, equals(parent));
        expect(parent.children.contains(first), isTrue);
        expect(parent.children.contains(second), isTrue);
      });
      test('values are scoped to each child', () {
        final first = parent.createChild([
          single<String>(() => 'first'),
        ]);

        final second = parent.createChild([
          single<String>(() => 'second'),
        ]);

        expect(first.observe<String>(), equals('first'));
        expect(second.observe<String>(), equals('second'));
      });
      test('disposing works', () {
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
    group('can access parent values', () {
      test('that already exist', () {
        helper
          ..addParentHeadValue()
          ..initLocators();

        expect(helper.parentHead, isHeadWith(count: 0)); // read parent first
        expect(helper.childHead, isHeadWith(count: 0));
        expect(helper.createCount, equals(1));
      });
      test('without overriding the value', () {
        helper
          ..addParentHeadValue()
          ..initLocators();

        expect(helper.childHead, isHeadWith(count: 0)); // read child first
        expect(helper.parentHead, isHeadWith(count: 0));
        expect(helper.createCount, equals(1));
      });
      test('that change due to observables', () async {
        final observable = helper.whereParentHeadObserves('x');

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

        expect(helper.createCount, equals(1));
        observable.setSingle('y');
        expect(helper.createCount, equals(2));
      });
      test('that change due to async updates', () async {
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

        expect(helper.createCount, equals(0));

        completer.complete('done');
        await pumpEventQueue();

        expect(helper.createCount, equals(1));
      });
      test('with old values passed to bind callback', () async {
        final cancelObservation = Completer<void>();

        helper
          ..addParentHeadValue()
          ..initLocators();

        final mutObservable = helper.whereParentHeadMutates('first');

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

        expect(
          helper.childHead,
          isHeadWith(mutValue: 'second', disposeCount: 0), // still zero
        );
      });
      test('that have errors', () {
        final throwable = helper.whereParentHeadThrows(FormatException());

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

        expect(helper.createCount, equals(0));
        throwable.setSingle(null);
        expect(helper.createCount, equals(1));
      });
    });
    group('can override parent values', () {
      test('with minimal recomputation', () {
        helper
          ..addParentHeadValue()
          ..addChildHeadValue()
          ..initLocators();

        expect(helper.createCount, equals(0));
        expect(helper.childHead, isHeadWith(count: 0));
        expect(helper.createCount, equals(1));
        expect(helper.parentHead, isHeadWith(count: 1));
        expect(helper.createCount, equals(2));

        expect(helper.parentHead, isHeadWith(count: 1));
        expect(helper.createCount, equals(2));
        expect(helper.childHead, isHeadWith(count: 0));
        expect(helper.createCount, equals(2));
      });
      test('while changing due to observables', () {
        final parentObs = helper.whereParentHeadObserves('a');
        final childObs = helper.whereChildHeadObserves('x');

        helper
          ..addParentHeadValue()
          ..addChildHeadValue()
          ..initLocators();

        expect(helper, hasCount(parentHead: 0, childHead: 0));

        expectObservableValue<Head>(
          () => helper.childHead,
          emitsInOrder(<dynamic>[
            isHeadWith(obsValue: 'x'),
            isHeadWith(obsValue: 'y'),
            isHeadWith(obsValue: 'z'),
          ]),
        );

        expect(helper, hasCount(parentHead: 0, childHead: 1));

        expectObservableValue<Head>(
          () => helper.parentHead,
          emitsInOrder(<dynamic>[
            isHeadWith(obsValue: 'a'),
            isHeadWith(obsValue: 'b'),
            isHeadWith(obsValue: 'c'),
          ]),
        );

        expect(helper, hasCount(parentHead: 1, childHead: 1));

        // Update child first
        childObs.setSingle('y');
        expect(helper, hasCount(parentHead: 1, childHead: 2));

        parentObs.setSingle('b');
        expect(helper, hasCount(parentHead: 2, childHead: 2));

        // Update parent first
        parentObs.setSingle('c');
        expect(helper, hasCount(parentHead: 3, childHead: 2));

        childObs.setSingle('z');
        expect(helper, hasCount(parentHead: 3, childHead: 3));
      });
      test('that change due to async updates', () async {
        final parentSink = helper.addParentHeadStream();
        final childSink = helper.addChildHeadStream();

        helper.initLocators();

        expect(helper, hasCount(parentHead: 0, childHead: 0, create: 0));

        // ignore: unawaited_futures
        expectObservableValue(
          () => helper.childHead,
          emitsInOrder(<dynamic>[
            emitsError(isA<LocatorValueMissingException>()),
            isHeadWith(value: 'x'),
            isHeadWith(value: 'y'),
          ]),
        );

        // ignore: unawaited_futures
        expectObservableValue(
          () => helper.parentHead,
          emitsInOrder(<dynamic>[
            emitsError(isA<LocatorValueMissingException>()),
            isHeadWith(value: 'a'),
            isHeadWith(value: 'b'),
          ]),
        );

        await pumpEventQueue();

        expect(helper, hasCount(parentHead: 1, childHead: 1, create: 0));

        parentSink.add('a');
        await pumpEventQueue();
        expect(helper, hasCount(parentHead: 1, childHead: 1, create: 1));

        childSink.add('x');
        await pumpEventQueue();
        expect(helper, hasCount(parentHead: 1, childHead: 1, create: 2));

        childSink.add('y');
        await pumpEventQueue();
        expect(helper, hasCount(parentHead: 1, childHead: 1, create: 3));

        parentSink.add('b');
        await pumpEventQueue();
        expect(helper, hasCount(parentHead: 1, childHead: 1, create: 4));
      });
      test('with old values passed to bind callback of child', () async {
        helper
          ..addParentHeadValue()
          ..addChildHeadValue()
          ..initLocators();

        final mutObservable = helper.whereChildHeadMutates('first');
        final cancelObservation = Completer<void>();

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

        expect(
          helper.childHead,
          isHeadWith(mutValue: 'second', disposeCount: 0), // still zero
        );
      });
      test('while having errors', () {
        helper
          ..addParentHeadValue(value: 'parentSuccess')
          ..addChildHeadValue(value: 'childSuccess')
          ..initLocators();

        final parentThrowable = helper.whereParentHeadThrows(null);
        final childThrowable = helper.whereChildHeadThrows(FormatException());

        expectObservableValue(
          () => helper.childHead,
          emitsInOrder(<dynamic>[
            emitsError(isFormatException),
            isHeadWith(value: 'childSuccess'),
          ]),
        );

        expectObservableValue(
          () => helper.parentHead,
          emitsInOrder(<dynamic>[
            isHeadWith(value: 'parentSuccess'),
            emitsError(isFormatException),
          ]),
        );

        expect(helper, hasCount(parentHead: 1, childHead: 1, create: 1));

        childThrowable.setSingle(null);
        expect(helper, hasCount(parentHead: 1, childHead: 2, create: 2));

        parentThrowable.setSingle(FormatException());
        expect(helper, hasCount(parentHead: 2, childHead: 2, create: 2));
      });
    });
    group('can depend on parent values', () {
      test('basic case', () {
        helper
          ..addParentTailValue(value: 'parent')
          ..addChildHeadValue(value: 'child', linkToTail: true)
          ..initLocators();

        expect(
          helper.childHead,
          isHeadWith(value: 'child', tailValue: 'parent', count: 1),
        );
        expect(helper.parentTail, isTailWith(value: 'parent', count: 0));
        expect(helper, hasCount(parentTail: 1, childHead: 1, create: 2));
      });
      test('that change due to observables', () {
        final observable = helper.whereParentTailObserves('first');

        helper
          ..addParentTailValue()
          ..addChildHeadValue(linkToTail: true)
          ..initLocators();

        expectObservableValue<Head>(
          () => helper.childHead,
          emitsInOrder(<dynamic>[
            isHeadWith(tailObsValue: 'first'),
            isHeadWith(tailObsValue: 'second'),
            isHeadWith(tailObsValue: 'third'),
          ]),
        );

        expect(helper, hasCount(parentTail: 1, childHead: 1, create: 2));

        observable.setSingle('second');
        expect(helper, hasCount(parentTail: 2, childHead: 2, create: 4));

        observable.setSingle('third');
        expect(helper, hasCount(parentTail: 3, childHead: 3, create: 6));
      });
    });
    group('can override intermediate values', () {
      test('basic case', () {
        helper
          ..addParentTailValue(value: 'original')
          ..addParentHeadValue(linkToTail: true)
          ..addChildTailValue(value: 'override')
          ..initLocators();

        // Construct parent head (and tail), then child tail, then child head
        expect(helper.childHead, isHeadWith(tailValue: 'override', count: 3));
        expect(
          helper,
          hasCount(
            parentHead: 2, // child uses parent head binder
            parentTail: 1, // parent tail used when constructing parent
            childHead: 0,
            childTail: 1,
            create: 4,
          ),
        );

        expect(helper.parentHead, isHeadWith(tailValue: 'original', count: 1));
        // Same counts, since same instances are reused
        expect(
          helper,
          hasCount(
            parentHead: 2,
            parentTail: 1,
            childHead: 0,
            childTail: 1,
            create: 4,
          ),
        );
      });
    });
  });
}
