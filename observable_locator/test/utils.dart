import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:observable_locator/observable_locator.dart';
import 'package:test/test.dart';

/// Asserts that each value emited by the MobX observable value matches
/// the given [StreamMatcher].
///
/// [cancelObservation] can be used to immediately end the observation
/// instead of waiting for the stream matcher to finish matching.
Future<void> expectObservableValue<T>(
  T Function() observeValue,
  StreamMatcher matcher, {
  Future<void>? cancelObservation,
  bool debugPrint = false,
}) async {
  final controller = StreamController<T>();

  final disposer = autorun((_) {
    try {
      final value = observeValue();
      if (debugPrint) print('DEBUG: $value');
      controller.add(value);
    } catch (e) {
      if (debugPrint) print('DEBUG: $e');
      controller.addError(e);
    }
  });

  // ignore: unawaited_futures
  cancelObservation?.then<void>((_) => controller.close());

  await expectLater(controller.stream, matcher);

  // ignore: unawaited_futures
  controller.close();
  disposer();
}

void expectAllObservableValues(
  Iterable<dynamic Function()> observeValues,
  StreamMatcher matcher, {
  Future<void>? cancelObservation,
  bool debugPrint = false,
}) {
  for (final observableValue in observeValues) {
    expectObservableValue(
      observableValue,
      matcher,
      cancelObservation: cancelObservation,
      debugPrint: debugPrint,
    );
  }
}

Iterable<T Function()> observeValuesOf<T>(
  Iterable<ObservableLocator> locators,
) =>
    locators.map((locator) => () => locator.observe<T>());

extension ObservableExtensions<T> on Observable<T> {
  void setSingle(T value) => Action(() => this.value = value).call();
}

class Box<T> {
  Box(this.value);

  final T value;
}

class Disposable {
  Disposable([this.name]);

  final String? name;
  String? description;

  var disposeCount = 0;

  void dispose() => disposeCount++;

  @override
  String toString() => '_Disposable { '
      'name: $name, '
      'description: $description, '
      'disposeCount: $disposeCount'
      '}';
}

Matcher emitsDisposableWith({
  String? name,
  String? description,
  int? disposeCount,
}) =>
    emits(predicate<Disposable>(
      (d) {
        final nameIsValid = name == null || d.name == name;
        final descriptionIsValid =
            description == null || d.description == description;
        final countIsValid =
            disposeCount != null || d.disposeCount == disposeCount;

        return nameIsValid && descriptionIsValid && countIsValid;
      },
      [
        if (name != null) 'has name of $name',
        if (description != null) 'has description of $description',
        if (disposeCount != null) 'has disposeCount of $disposeCount',
      ].join(', '),
    ));
