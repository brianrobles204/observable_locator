import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';

/// Boilerplate test setup code for MobX tests.
///
/// Sets the write policy of [mainContext] to never throw, allowing for mutation
/// of observables outside of an [Action] call. Convenient behavior for tests
/// that mutate observables predictably.
void setupMobXTest() {
  setUp(() => mainContext.config =
      ReactiveConfig(writePolicy: ReactiveWritePolicy.never));

  tearDown(() => mainContext.config = ReactiveConfig.main);
}
