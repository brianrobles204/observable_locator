import 'package:flutter/widgets.dart' hide Action;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_observable_locator/flutter_observable_locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:observable_locator/observable_locator.dart';

void main() {
  testWidgets('default constructor provides a locator', (tester) async {
    final observable = Observable('first');

    await tester.pumpWidget(
      ObservableLocatorScope(
        init: (locator) {
          locator.register<String>((_) => observable.value);
        },
        child: _ToStringObserver<String>(),
      ),
    );

    expect(find.text('first'), findsOneWidget);

    observable.setSingle('second');
    await tester.pump();

    expect(find.text('second'), findsOneWidget);
  });
  testWidgets('throws if shadowing another locator', (tester) async {
    await tester.pumpWidget(
      ObservableLocatorScope(
        init: _noop,
        child: ObservableLocatorScope(
          init: _noop,
          child: Container(),
        ),
      ),
    );

    expect(tester.takeException(), isFlutterError);
  });
  testWidgets('.value throws if locator changes', (tester) async {
    await tester.pumpWidget(
      ObservableLocatorScope.value(
        ObservableLocator.writable(),
        child: Container(),
      ),
    );

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      ObservableLocatorScope.value(
        ObservableLocator.writable(),
        child: Container(),
      ),
    );

    expect(tester.takeException(), isFlutterError);
  });
  testWidgets('.child subtree is scoped to child locator', (tester) async {
    final main = _Disposable('main');
    final sub = _Disposable('sub');

    InitLocator initWith(_Disposable value) {
      return (WritableObservableLocator locator) {
        locator.register<_Disposable>(
          (_) => value,
          dispose: (value) => value.dispose(),
        );
      };
    }

    Widget buildWidget({
      required Key mainKey,
      required bool showSub,
    }) =>
        ObservableLocatorScope(
          key: mainKey,
          init: initWith(main),
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              _ToStringObserver<_Disposable>(tag: 'parent'),
              if (showSub)
                ObservableLocatorScope.child(
                  init: initWith(sub),
                  child: _ToStringObserver<_Disposable>(tag: 'child'),
                ),
            ],
          ),
        );

    await tester.pumpWidget(
      buildWidget(mainKey: ValueKey('first'), showSub: true),
    );

    expect(find.text('parent: main'), findsOneWidget);
    expect(find.text('child: sub'), findsOneWidget);
    expect(main.disposeCount, equals(0));
    expect(sub.disposeCount, equals(0));

    await tester.pumpWidget(
      buildWidget(mainKey: ValueKey('first'), showSub: false),
    );

    expect(find.text('parent: main'), findsOneWidget);
    expect(find.text('child: sub'), findsNothing);
    expect(main.disposeCount, equals(0));
    expect(sub.disposeCount, equals(1));

    await tester.pumpWidget(
      buildWidget(mainKey: ValueKey('first'), showSub: true),
    );

    expect(find.text('parent: main'), findsOneWidget);
    expect(find.text('child: sub'), findsOneWidget);
    expect(main.disposeCount, equals(0));
    expect(sub.disposeCount, equals(1));

    await tester.pumpWidget(
      buildWidget(mainKey: ValueKey('second'), showSub: true),
    );

    expect(find.text('parent: main'), findsOneWidget);
    expect(find.text('child: sub'), findsOneWidget);
    expect(main.disposeCount, equals(1));
    expect(sub.disposeCount, equals(2));
  });
  testWidgets('RegisterProxyObservable works', (tester) async {
    Widget buildWidget(TextDirection textDirection) => ObservableLocatorScope(
          init: _noop,
          child: Directionality(
            textDirection: textDirection,
            child: RegisterProxyObservable(
              update: (context) => Directionality.of(context),
              child: Observer(
                builder: (context) =>
                    Text(context.observe<TextDirection>().toString()),
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildWidget(TextDirection.ltr));

    expect(find.text(TextDirection.ltr.toString()), findsOneWidget);

    await tester.pumpWidget(buildWidget(TextDirection.rtl));

    expect(find.text(TextDirection.rtl.toString()), findsOneWidget);
  });
  testWidgets('RegisterMultiProxyObservable works', (tester) async {
    const firstOrder = NumericFocusOrder(1);
    const secondOrder = NumericFocusOrder(2);

    Widget buildWidget(
      TextDirection textDirection,
      FocusOrder order,
    ) =>
        ObservableLocatorScope(
          init: _noop,
          child: Directionality(
            textDirection: textDirection,
            child: FocusTraversalOrder(
              order: order,
              child: RegisterMultiProxyObservable(
                initUpdateBuilders: () => [
                  UpdateBuilder<TextDirection>(Directionality.of),
                  UpdateBuilder<FocusOrder>(FocusTraversalOrder.of),
                ],
                child: Observer(
                  builder: (context) => Column(
                    children: [
                      Text(context.observe<TextDirection>().toString()),
                      Text(context.observe<FocusOrder>().toString()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildWidget(TextDirection.ltr, firstOrder));

    expect(find.text(TextDirection.ltr.toString()), findsOneWidget);
    expect(find.text(firstOrder.toString()), findsOneWidget);

    await tester.pumpWidget(buildWidget(TextDirection.rtl, secondOrder));

    expect(find.text(TextDirection.rtl.toString()), findsOneWidget);
    expect(find.text(secondOrder.toString()), findsOneWidget);
  });
  testWidgets('RegisterValue works', (tester) async {
    Widget buildWidget(String content) => ObservableLocatorScope(
          init: _noop,
          child: RegisterValue<String>(
            value: content,
            child: Observer(
              builder: (context) => Text(
                context.observe<String>(),
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildWidget('first'));

    expect(find.text('first'), findsOneWidget);

    await tester.pumpWidget(buildWidget('second'));

    expect(find.text('second'), findsOneWidget);
  });
}

void _noop<T>(T _) => null;

class _Disposable {
  _Disposable(this.name);

  final String name;

  int disposeCount = 0;

  void dispose() {
    disposeCount++;
  }

  @override
  String toString() => name;
}

class _ToStringObserver<T> extends StatelessObserverWidget {
  const _ToStringObserver({
    Key? key,
    this.tag,
  }) : super(key: key);

  final String? tag;

  @override
  Widget build(BuildContext context) {
    final tagText = tag != null ? '$tag: ' : '';

    return Text(
      tagText + context.observe<T>().toString(),
      textDirection: TextDirection.ltr,
    );
  }
}

extension _ObservableExtensions<T> on Observable<T> {
  void setSingle(T value) => Action(() => this.value = value).call();
}
