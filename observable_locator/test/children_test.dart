import 'package:mobx/mobx.dart';
import 'package:observable_locator/observable_locator.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('children', () {
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

    test('can access parent registered values', () {
      var count = 0;
      final createBox = () => Box(count++);

      locator = ObservableLocator([
        single<Box>(() => createBox()),
      ]);

      final child = locator.createChild([]);
      expect(child.parent, equals(locator));

      final disposeWatcher = autorun((_) => child.observe<Box>());

      expect(child.observe<Box>().value, equals(0));
      expect(locator.observe<Box>().value, equals(0));
      expect(count, equals(1));

      disposeWatcher();
    });
    test('can depend on parent values', () {
      locator = ObservableLocator([
        single<Box>(() => Box('value')),
      ]);

      final child = locator.createChild([
        Binder<String>((locator, _) => locator.observe<Box>().value),
      ]);

      expect(child.observe<String>(), equals('value'));
    });
    test('can override values of the parent', () {
      locator = ObservableLocator([
        single<int>(() => 100),
      ]);

      final child = locator.createChild([
        single<int>(() => 200),
      ]);

      expect(child.observe<int>(), equals(200));
      expect(locator.observe<int>(), equals(100));
    });
    test('values are scoped to each child', () {
      locator = ObservableLocator([]);

      final first = locator.createChild([
        single<String>(() => 'first'),
      ]);

      final second = locator.createChild([
        single<String>(() => 'second'),
      ]);

      expect(first.observe<String>(), equals('first'));
      expect(second.observe<String>(), equals('second'));
    });
    test('can override intermediate values', () {
      locator = ObservableLocator([
        single<int>(() => 1),
        Binder<String>((locator, _) => locator.observe<int>().toString()),
      ]);

      final child = locator.createChild([
        single<int>(() => 2),
      ]);

      expect(child.observe<String>(), equals('2'));
    });
    test('can depend on values with changing intermediate dependencies', () {
      final observable = Observable(100);
      locator = ObservableLocator([
        single<int>(() => observable.value),
      ]);

      final child = locator.createChild([
        Binder<String>((_, __) => locator.observe<int>().toString()),
      ]);

      expectObservableValue<String>(
        child.observe,
        emitsInOrder(<dynamic>[
          equals('100'),
          equals('200'),
          equals('300'),
        ]),
      );

      observable.setSingle(200);
      observable.setSingle(300);
    });
    test('disposing works', () {
      locator = ObservableLocator([]);

      final disposable = Disposable();
      final child = locator.createChild([
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
      locator = ObservableLocator([]);

      final xDisposable = Disposable();
      final x = locator.createChild([
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
