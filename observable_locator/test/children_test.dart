import 'dart:async';

import 'package:mobx/mobx.dart';
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
      test('disposing a child will not dispose parent state', () {
        final xDisposable = Disposable();
        final x = parent.createChild([
          single<Disposable>(
            () => xDisposable,
            dispose: (value) => value.dispose(),
          ),
        ]);

        final x1 = x.createChild();

        expect(x1.observe<Disposable>().disposeCount, equals(0));
        expect(x1.observe<Disposable>(), same(x.observe<Disposable>()));

        x1.dispose();
        expect(x.observe<Disposable>().disposeCount, equals(0));
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
      test('while avoiding unecessary updates due to different deps', () {
        final tailObs = helper.whereParentTailObserves('first');
        final shouldUseTail = Observable(true);

        helper
          ..addParentTailValue()
          ..addParentHeadOverride(bind<Head>((locator) {
            return shouldUseTail.value
                ? Head(-1, tailObsValue: locator.observe<Tail>().obsValue)
                : Head(-2, tailObsValue: 'no update');
          }))
          ..initLocators();

        expectAllObservableValues(
          helper.allLocatorsObserve<Head>(),
          emitsInOrder(<dynamic>[
            isHeadWith(count: -1, tailObsValue: 'first'),
            isHeadWith(count: -2, tailObsValue: 'no update'),
            isHeadWith(count: -1, tailObsValue: 'third'),
          ]),
        );

        shouldUseTail.setSingle(false);
        tailObs.setSingle('second');
        tailObs.setSingle('third');
        shouldUseTail.setSingle(true);
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
      test('without being affected by parent dependencies', () {
        final tailObs = helper.whereParentTailObserves('first');
        final cancelObservation = Completer<void>();

        helper
          ..addParentTailValue()
          ..addParentHeadValue(linkToTail: true)
          ..addChildHeadValue()
          ..initLocators();

        expectObservableValue(
          () => helper.childHead,
          emitsInOrder(<dynamic>[
            isHeadWith(tailObsValue: null, count: 0),
            emitsDone,
          ]),
          cancelObservation: cancelObservation.future,
        );

        expect(helper, hasCount(childHead: 1, create: 1));

        expectObservableValue(
          () => helper.parentHead,
          emitsInOrder(<dynamic>[
            isHeadWith(tailObsValue: 'first', count: 2),
            isHeadWith(tailObsValue: 'second', count: 4),
            emitsDone,
          ]),
          cancelObservation: cancelObservation.future,
        );

        expect(
          helper,
          hasCount(childHead: 1, parentTail: 1, parentHead: 1, create: 3),
        );

        tailObs.setSingle('second');
        expect(
          helper,
          hasCount(childHead: 1, parentTail: 2, parentHead: 2, create: 5),
        );

        cancelObservation.complete();
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
      // Initial count after reading the child head.
      // > Create parent head (& tail), then child tail, then child head
      final hasInitialCount = hasCount(
        parentHead: 2, // child uses parent head binder
        parentTail: 1, // parent tail used when constructing parent
        childHead: 0,
        childTail: 1,
        create: 4,
      );

      test('basic case', () {
        helper
          ..addParentTailValue(value: 'original')
          ..addParentHeadValue(linkToTail: true)
          ..addChildTailValue(value: 'override')
          ..initLocators();

        expect(helper.childHead, isHeadWith(tailValue: 'override', count: 3));
        expect(helper, hasInitialCount);

        expect(helper.parentHead, isHeadWith(tailValue: 'original', count: 1));
        expect(helper, hasInitialCount); // Same, since instances are reused
      });
      test('while changing due to observables', () {
        helper
          ..addParentTailValue(value: 'original')
          ..addParentHeadValue(linkToTail: true)
          ..addChildTailValue(value: 'override')
          ..initLocators();

        final parentTailObs = helper.whereParentTailObserves('first');
        final childTailObs = helper.whereChildTailObserves('uno');
        final parentHeadObs = helper.whereParentHeadObserves('apple');

        expectObservableValue(
          () => helper.childHead,
          emitsInOrder(<dynamic>[
            isHeadWith(tailValue: 'override', tailObsValue: 'uno', count: 3),
            isHeadWith(tailValue: 'override', tailObsValue: 'dos', count: 7),
            isHeadWith(tailValue: 'override', tailObsValue: 'tres', count: 9),
            isHeadWith(obsValue: 'blueberry', tailValue: 'override', count: 13),
          ]),
          name: 'childHead',
        );

        expect(helper, hasInitialCount);

        expectObservableValue(
          () => helper.parentHead,
          emitsInOrder(<dynamic>[
            isHeadWith(tailValue: 'original', tailObsValue: 'first', count: 1),
            isHeadWith(tailValue: 'original', tailObsValue: 'second', count: 5),
            isHeadWith(tailValue: 'original', tailObsValue: 'third', count: 11),
            isHeadWith(obsValue: 'blueberry', tailValue: 'original', count: 12),
          ]),
          name: 'parentHead',
        );

        expect(helper, hasInitialCount);

        parentTailObs.setSingle('second');
        expect(
          helper,
          hasCount(
            parentHead: 3,
            parentTail: 2,
            childHead: 0,
            childTail: 1,
            create: 6,
          ),
        );

        childTailObs.setSingle('dos');
        expect(
          helper,
          hasCount(
            parentHead: 4,
            parentTail: 2,
            childHead: 0,
            childTail: 2,
            create: 8,
          ),
        );

        childTailObs.setSingle('tres');
        expect(
          helper,
          hasCount(
            parentHead: 5,
            parentTail: 2,
            childHead: 0,
            childTail: 3,
            create: 10,
          ),
        );

        parentTailObs.setSingle('third');
        expect(
          helper,
          hasCount(
            parentHead: 6,
            parentTail: 3,
            childHead: 0,
            childTail: 3,
            create: 12,
          ),
        );

        parentHeadObs.setSingle('blueberry');
        expect(
          helper,
          hasCount(
            parentHead: 8,
            parentTail: 3,
            childHead: 0,
            childTail: 3,
            create: 14,
          ),
        );
      });
      test('without changing final values, if they are equal', () async {
        final equalTailObs = Observable<Tail>(Tail(-1, value: 'equal'));
        final diffTailObs = Observable<Tail>(Tail(-100, value: 'different'));
        final shouldBeEqual = Observable<bool>(true);

        final parentHeadObs = helper.whereParentHeadObserves('first');
        Tail? prevChildTail;

        helper
          ..addParentTailOverride(single(() => equalTailObs.value))
          ..addChildTailOverride(bindValue(
            (_, tail) {
              prevChildTail = tail;
              return shouldBeEqual.value
                  ? equalTailObs.value
                  : diffTailObs.value;
            },
          ))
          ..addParentHeadValue(linkToTail: true)
          ..initLocators();

        // ignore: unawaited_futures
        expectObservableValue(
          () => helper.childHead,
          emitsInOrder(<dynamic>[
            isNewHeadWith(tailValue: 'equal', obsValue: 'first', count: 0),
            isNewHeadWith(
                tailValue: 'still equal', obsValue: 'first', count: 1),
            isNewHeadWith(
                tailValue: 'still equal', obsValue: 'second', count: 2),
            isNewHeadWith(tailValue: 'different', obsValue: 'second', count: 3),
            isNewHeadWith(
                tailValue: 'still diff', obsValue: 'second', count: 5),
            isNewHeadWith(tailValue: 'still diff', obsValue: 'third', count: 7),
            isNewHeadWith(tailValue: 'still div', obsValue: 'third', count: 9),
          ]),
        );

        // ignore: unawaited_futures
        expectObservableValue(
          () => helper.parentHead,
          emitsInOrder(<dynamic>[
            isNewHeadWith(tailValue: 'equal', obsValue: 'first', count: 0),
            isNewHeadWith(
                tailValue: 'still equal', obsValue: 'first', count: 1),
            isNewHeadWith(
                tailValue: 'still equal', obsValue: 'second', count: 2),
            isNewHeadWith(tailValue: 'diverged', obsValue: 'second', count: 4),
            isNewHeadWith(tailValue: 'diverged', obsValue: 'third', count: 6),
            isNewHeadWith(tailValue: 'still div', obsValue: 'third', count: 8),
          ]),
        );

        await pumpEventQueue();
        expect(helper.childHead, same(helper.parentHead));
        expect(helper, hasCount(parentHead: 1));

        equalTailObs.setSingle(Tail(-2, value: 'still equal'));
        await pumpEventQueue();
        expect(helper.childHead, same(helper.parentHead));
        expect(helper, hasCount(parentHead: 2));

        parentHeadObs.setSingle('second');
        await pumpEventQueue();
        expect(helper.childHead, same(helper.parentHead));
        expect(helper, hasCount(parentHead: 3));

        shouldBeEqual.setSingle(false);
        await pumpEventQueue();
        expect(helper.childHead, isNot(same(helper.parentHead)));
        expect(helper.parentHead, isHeadWith(disposeCount: 0));
        expect(prevChildTail, same(helper.parentTail));
        expect(helper, hasCount(parentHead: 4));

        equalTailObs.setSingle(Tail(-3, value: 'diverged'));
        await pumpEventQueue();
        expect(helper, hasCount(parentHead: 5));

        diffTailObs.setSingle(Tail(-200, value: 'still diff'));
        await pumpEventQueue();
        expect(helper, hasCount(parentHead: 6));

        parentHeadObs.setSingle('third');
        await pumpEventQueue();
        expect(helper, hasCount(parentHead: 8)); // both parent & child update

        equalTailObs.setSingle(Tail(-4, value: 'still div'));
        expect(helper, hasCount(parentHead: 9));

        // Will not converge anymore even if intermediate values are the same
        shouldBeEqual.setSingle(true);
        expect(helper.childHead, isNot(same(helper.parentHead)));
        expect(helper, hasCount(parentHead: 10));

        await pumpEventQueue();
      });
      test('while also changing due to async updates', () async {
        final parentTailSink = helper.addParentTailStream();
        final parentHeadSink = helper.addParentHeadStream(
            pendingValue: 'pending', linkToTail: true);
        final childTailSink = helper.addChildTailStream();
        helper.initLocators();

        // ignore: unawaited_futures
        expectObservableValue(
          () => helper.childHead,
          emitsInOrder(<dynamic>[
            emitsError(isA<LocatorValueMissingException>()),
            isHeadWith(value: 'pending', tailValue: null, count: 0),
            isHeadWith(value: 'ph-1', tailValue: 'ct-1', count: 3),
            isHeadWith(value: 'ph-2', tailValue: 'ct-1', count: 6),
            isHeadWith(value: 'pending', tailValue: null, count: 0), // orig
            isHeadWith(value: 'ph-3', tailValue: 'ct-2', count: 10),
          ]),
        );

        await pumpEventQueue();
        final hasInitialAsyncCount = hasCount(
          parentHead: 2,
          childHead: 0,
          parentTail: 1,
          childTail: 1,
          create: 1, // pending value
        );
        expect(helper, hasInitialAsyncCount);

        // ignore: unawaited_futures
        expectObservableValue(
          () => helper.parentHead,
          emitsInOrder(<dynamic>[
            emitsError(isA<LocatorValueMissingException>()),
            isHeadWith(value: 'pending', tailValue: null, count: 0),
            isHeadWith(value: 'ph-1', tailValue: 'pt-1', count: 4),
            isHeadWith(value: 'pending', tailValue: null, count: 0), // orig
            isHeadWith(value: 'ph-2', tailValue: 'pt-2', count: 7),
            isHeadWith(value: 'ph-3', tailValue: 'pt-2', count: 9),
          ]),
        );

        await pumpEventQueue();
        expect(helper, hasInitialAsyncCount);

        childTailSink.add('ct-1');
        await pumpEventQueue();
        expect(
          helper,
          hasCount(
            parentHead: 3,
            childHead: 0,
            parentTail: 1,
            childTail: 1,
            create: 2,
          ),
        );

        parentTailSink.add('pt-1');
        await pumpEventQueue();
        expect(
          helper,
          hasCount(
            parentHead: 4,
            childHead: 0,
            parentTail: 1,
            childTail: 1,
            create: 3,
          ),
        );

        parentHeadSink.add('ph-1');
        await pumpEventQueue();
        expect(
          helper,
          hasCount(
            parentHead: 4,
            childHead: 0,
            parentTail: 1,
            childTail: 1,
            create: 5,
          ),
        );

        parentTailSink.add('pt-2');
        await pumpEventQueue();
        expect(
          helper,
          hasCount(
            parentHead: 5,
            childHead: 0,
            parentTail: 1,
            childTail: 1,
            create: 6,
          ),
        );

        parentHeadSink.add('ph-2');
        await pumpEventQueue();
        expect(
          helper,
          hasCount(
            parentHead: 5,
            childHead: 0,
            parentTail: 1,
            childTail: 1,
            create: 8,
          ),
        );

        childTailSink.add('ct-2');
        await pumpEventQueue();
        expect(
          helper,
          hasCount(
            parentHead: 6,
            childHead: 0,
            parentTail: 1,
            childTail: 1,
            create: 9,
          ),
        );

        parentHeadSink.add('ph-3');
        await pumpEventQueue();
        expect(
          helper,
          hasCount(
            parentHead: 6,
            childHead: 0,
            parentTail: 1,
            childTail: 1,
            create: 11,
          ),
        );
      });
      test('while handling errors', () {
        final ptThrowable = helper.whereParentTailThrows(FormatException());
        final ctThrowable = helper.whereChildTailThrows(FormatException());

        helper
          ..addParentTailValue(value: 'original')
          ..addChildTailValue(value: 'override')
          ..addParentHeadValue(linkToTail: true)
          ..initLocators();

        expectObservableValue(
          () => helper.childHead,
          emitsInOrder(<dynamic>[
            emitsError(isFormatException),
            emitsError(isNullThrownError),
            isHeadWith(tailValue: 'override', count: 3),
          ]),
        );

        final hasInitialErrorCount = hasCount(
          parentHead: 2,
          childHead: 0,
          parentTail: 1,
          childTail: 1,
          create: 0,
        );
        expect(helper, hasInitialErrorCount);

        expectObservableValue(
          () => helper.parentHead,
          emitsInOrder(<dynamic>[
            emitsError(isFormatException),
            isHeadWith(tailValue: 'original', count: 1),
          ]),
        );

        expect(helper, hasInitialErrorCount);

        ctThrowable.setSingle(NullThrownError());
        expect(
          helper,
          hasCount(
            parentHead: 3,
            childHead: 0,
            parentTail: 1,
            childTail: 2,
            create: 0,
          ),
        );

        ptThrowable.setSingle(null);
        expect(
          helper,
          hasCount(
            parentHead: 4,
            childHead: 0,
            parentTail: 2,
            childTail: 2,
            create: 2,
          ),
        );

        ctThrowable.setSingle(null);
        expect(
          helper,
          hasCount(
            parentHead: 5,
            childHead: 0,
            parentTail: 2,
            childTail: 3,
            create: 4,
          ),
        );
      });
    });
  });
}
