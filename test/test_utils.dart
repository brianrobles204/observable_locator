import 'dart:async';

import 'package:mobx/mobx.dart';
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
