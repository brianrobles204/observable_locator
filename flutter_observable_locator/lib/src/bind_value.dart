import 'package:flutter/widgets.dart' hide Action;
import 'package:mobx/mobx.dart';
import 'package:nested/nested.dart';
import 'package:observable_locator/observable_locator.dart';

import 'observable_locator_scope.dart';

class BindValue<T> extends SingleChildStatefulWidget {
  const BindValue({
    Key? key,
    required this.value,
    this.builder,
    Widget? child,
  }) : super(key: key, child: child);

  final T value;
  final TransitionBuilder? builder;

  @override
  _BindValueState<T> createState() => _BindValueState();
}

class _BindValueState<T> extends SingleChildState<BindValue<T>> {
  late final _observable = Observable<T>(widget.value);

  @override
  void didUpdateWidget(covariant BindValue<T> oldWidget) {
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
      create: () => [single<T>(() => _observable.value)],
      builder: widget.builder,
      child: child,
    );
  }
}
