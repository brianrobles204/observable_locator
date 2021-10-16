import 'package:flutter/widgets.dart';
import 'package:flutter_observable_locator/flutter_observable_locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:observable_locator/observable_locator.dart';

import 'test_utils.dart';

void main() {
  group('Locator Reaction State Mixin', () {
    setupMobXTest();

    final shouldDispose = Observable<bool>(false);
    final shouldDisposeBinder = single<bool>(() => shouldDispose.value);

    testWidgets('autorun works', (tester) async {
      final observable = Observable<int>(1);
      final box = _Box<int>(-1);

      await tester.pumpWidget(
        ObservableLocatorScope(
          create: () => [
            single<int>(() => observable.value),
            shouldDisposeBinder,
          ],
          child: _AutorunTestWidget<int>(box: box),
        ),
      );

      expect(box.value, equals(1));

      observable.value = 2;
      expect(box.value, equals(2));

      await tester.pumpWidget(Container());

      observable.value = 3;
      expect(box.value, equals(2), reason: 'widget was disposed');
    });
    testWidgets('autorun works after locator change', (tester) async {
      final childKey = GlobalKey();
      final box = _Box<int>(-1);

      final firstObs = Observable<int>(1);
      await tester.pumpWidget(
        ObservableLocatorScope(
          key: Key('first'),
          create: () => [
            single<int>(() => firstObs.value),
            shouldDisposeBinder,
          ],
          child: _AutorunTestWidget<int>(key: childKey, box: box),
        ),
      );

      expect(box.value, equals(1));

      firstObs.value = 2;
      expect(box.value, equals(2));

      final secondObs = Observable<int>(10);
      await tester.pumpWidget(
        ObservableLocatorScope(
          key: Key('second'),
          create: () => [
            single<int>(() => secondObs.value),
            shouldDisposeBinder,
          ],
          child: _AutorunTestWidget<int>(key: childKey, box: box),
        ),
      );

      expect(box.value, equals(10));

      firstObs.value = 3;
      expect(box.value, equals(10));

      secondObs.value = 20;
      expect(box.value, equals(20));
    });
    testWidgets('autorun can be disposed by callback reaction', (tester) async {
      final observable = Observable<int>(1);
      final box = _Box<int>(-1);

      await tester.pumpWidget(
        ObservableLocatorScope(
          create: () => [
            single<int>(() => observable.value),
            shouldDisposeBinder,
          ],
          child: _AutorunTestWidget<int>(box: box),
        ),
      );

      expect(box.value, equals(1));

      observable.value = 2;
      expect(box.value, equals(2));

      runInAction(() {
        shouldDispose.value = true;
        observable.value = 3;
      });

      expect(box.value, equals(3));

      observable.value = 4;
      expect(box.value, equals(3), reason: 'no change, reaction is disposed');

      runInAction(() {
        shouldDispose.value = false;
        observable.value = 5;
      });

      expect(box.value, equals(3), reason: 'reaction still disposed');

      observable.value = 6;
      expect(box.value, equals(3));

      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });
    testWidgets('autorun can be disposed via disposer', (tester) async {
      final observable = Observable<int>(1);

      final firstBox = _Box<int>(-1);
      await tester.pumpWidget(
        ObservableLocatorScope(
          create: () => [
            single<int>(() => observable.value),
            shouldDisposeBinder,
          ],
          child: _AutorunTestWidget<int>(box: firstBox),
        ),
      );

      expect(firstBox.value, equals(1));

      observable.value = 2;
      expect(firstBox.value, equals(2));

      final secondBox = _Box<int>(-1);
      await tester.pumpWidget(
        ObservableLocatorScope(
          create: () => [
            single<int>(() => observable.value),
            shouldDisposeBinder,
          ],
          child: _AutorunTestWidget<int>(box: secondBox), // use second box
        ),
      );

      expect(secondBox.value, equals(2));

      observable.value = 3;
      expect(firstBox.value, equals(2));
      expect(secondBox.value, equals(3));

      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });
    testWidgets('reaction works', (tester) async {
      final observable = Observable<int>(1);
      final box = _Box<int>(-1);

      await tester.pumpWidget(
        ObservableLocatorScope(
          create: () => [
            single<int>(() => observable.value),
            shouldDisposeBinder,
          ],
          child: _ReactionTestWidget<int>(box: box),
        ),
      );

      expect(box.value, equals(-1), reason: 'not fired immediately');

      observable.value = 2;
      expect(box.value, equals(2));

      await tester.pumpWidget(Container());

      observable.value = 3;
      expect(box.value, equals(2), reason: 'widget was disposed');
    });
    testWidgets('reaction works after locator change', (tester) async {
      final childKey = GlobalKey();
      final box = _Box<int>(-1);

      final firstObs = Observable<int>(1);
      await tester.pumpWidget(
        ObservableLocatorScope(
          key: Key('first'),
          create: () => [
            single<int>(() => firstObs.value),
            shouldDisposeBinder,
          ],
          child: _ReactionTestWidget<int>(key: childKey, box: box),
        ),
      );

      expect(box.value, equals(-1), reason: 'not fired immediately');

      firstObs.value = 2;
      expect(box.value, equals(2));

      final secondObs = Observable<int>(10);
      await tester.pumpWidget(
        ObservableLocatorScope(
          key: Key('second'),
          create: () => [
            single<int>(() => secondObs.value),
            shouldDisposeBinder,
          ],
          child: _ReactionTestWidget<int>(key: childKey, box: box),
        ),
      );

      expect(box.value, equals(2), reason: 'not fired immediately');

      firstObs.value = 3;
      expect(box.value, equals(2));

      secondObs.value = 20;
      expect(box.value, equals(20));
    });
    testWidgets('reactions can be disposed in callback', (tester) async {
      final observable = Observable<int>(1);
      final box = _Box<int>(-1);

      await tester.pumpWidget(
        ObservableLocatorScope(
          create: () => [
            single<int>(() => observable.value),
            shouldDisposeBinder,
          ],
          child: _ReactionTestWidget<int>(box: box),
        ),
      );

      expect(box.value, equals(-1));

      observable.value = 2;
      expect(box.value, equals(2));

      runInAction(() {
        shouldDispose.value = true;
        observable.value = 3;
      });

      expect(box.value, equals(3));

      observable.value = 4;
      expect(box.value, equals(3), reason: 'no change, reaction is disposed');

      runInAction(() {
        shouldDispose.value = false;
        observable.value = 5;
      });

      expect(box.value, equals(3), reason: 'reaction still disposed');

      observable.value = 6;
      expect(box.value, equals(3));

      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });
    testWidgets('reactions can be disposed via disposer', (tester) async {
      final observable = Observable<int>(1);

      final firstBox = _Box<int>(-1);
      await tester.pumpWidget(
        ObservableLocatorScope(
          create: () => [
            single<int>(() => observable.value),
            shouldDisposeBinder,
          ],
          child: _ReactionTestWidget<int>(box: firstBox),
        ),
      );

      expect(firstBox.value, equals(-1));

      observable.value = 2;
      expect(firstBox.value, equals(2));

      final secondBox = _Box<int>(-1);
      await tester.pumpWidget(
        ObservableLocatorScope(
          create: () => [
            single<int>(() => observable.value),
            shouldDisposeBinder,
          ],
          child: _ReactionTestWidget<int>(box: secondBox), // use second box
        ),
      );

      expect(secondBox.value, equals(-1));

      observable.value = 3;
      expect(firstBox.value, equals(2));
      expect(secondBox.value, equals(3));

      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
    });
  });
}

class _Box<T> {
  _Box(this.value);

  T value;
}

/// Widget that autoruns, observing `T` in the locator and setting the value of
/// [box] to the locator's `T` value
class _AutorunTestWidget<T> extends StatefulWidget {
  const _AutorunTestWidget({
    Key? key,
    required this.box,
  }) : super(key: key);

  final _Box<T> box;

  @override
  _AutorunTestWidgetState<T> createState() => _AutorunTestWidgetState();
}

class _AutorunTestWidgetState<T> extends State<_AutorunTestWidget<T>>
    with LocatorReactionStateMixin {
  ReactionDisposer? disposeAutorun;

  @override
  void initState() {
    super.initState();
    _updateAutorun();
  }

  @override
  void didUpdateWidget(covariant _AutorunTestWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.box != widget.box) {
      _updateAutorun();
    }
  }

  void _updateAutorun() {
    disposeAutorun?.call();
    disposeAutorun = autorunWithLocator((reaction, locator) {
      final shouldDispose = locator.tryObserve<bool>();
      if (shouldDispose ?? false) {
        reaction.dispose();
      }

      widget.box.value = locator.observe<T>();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class _ReactionTestWidget<T> extends StatefulWidget {
  const _ReactionTestWidget({
    Key? key,
    required this.box,
  }) : super(key: key);

  final _Box<T> box;

  @override
  _ReactionTestWidgetState<T> createState() => _ReactionTestWidgetState();
}

class _ReactionTestWidgetState<T> extends State<_ReactionTestWidget<T>>
    with LocatorReactionStateMixin {
  ReactionDisposer? disposeReaction;

  @override
  void initState() {
    super.initState();
    _updateReaction();
  }

  @override
  void didUpdateWidget(covariant _ReactionTestWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.box != widget.box) {
      _updateReaction();
    }
  }

  void _updateReaction() {
    disposeReaction?.call();
    disposeReaction = reactionWithLocator<T>(
      (reaction, locator) {
        final shouldDispose = locator.tryObserve<bool>();
        if (shouldDispose ?? false) {
          reaction.dispose();
        }

        return locator.observe<T>();
      },
      (value) => widget.box.value = value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
