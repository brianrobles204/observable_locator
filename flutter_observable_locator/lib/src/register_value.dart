import 'package:flutter/widgets.dart' hide Action;
import 'package:mobx/mobx.dart';
import 'package:nested/nested.dart';

import 'observable_locator_scope.dart';

class RegisterValue<T> extends SingleChildStatefulWidget {
  const RegisterValue({
    Key? key,
    required this.value,
    this.builder,
    Widget? child,
  }) : super(key: key, child: child);

  final T value;
  final TransitionBuilder? builder;

  @override
  _RegisterValueState<T> createState() => _RegisterValueState();
}

class _RegisterValueState<T> extends SingleChildState<RegisterValue<T>> {
  late final _observable = Observable<T>(widget.value);

  @override
  void didUpdateWidget(covariant RegisterValue<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value != _observable.value) {
      Action(() => _observable.value = widget.value)();
    }
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    assert(
      widget.builder != null || child != null,
      '$runtimeType used outside of Nested must specify a child',
    );

    return ObservableLocatorScope.child(
      init: (locator) {
        locator.register<T>((_) => _observable.value);
      },
      builder: widget.builder,
      child: child,
    );
  }
}
