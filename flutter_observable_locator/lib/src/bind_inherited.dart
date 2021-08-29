import 'package:flutter/widgets.dart' hide Action;
import 'package:mobx/mobx.dart';
import 'package:nested/nested.dart';
import 'package:observable_locator/observable_locator.dart';

import 'observable_locator_scope.dart';

typedef Update<T> = T Function(BuildContext context);

class BindInherited<T> extends SingleChildStatefulWidget {
  const BindInherited({
    Key? key,
    required this.update,
    this.builder,
    Widget? child,
  }) : super(key: key, child: child);

  final Update<T> update;
  final TransitionBuilder? builder;

  @override
  _BindInheritedState<T> createState() => _BindInheritedState();
}

class _BindInheritedState<T> extends SingleChildState<BindInherited<T>> {
  Observable<T>? observable;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final value = widget.update(context);
    if (observable != null) {
      Action(() => observable!.value = value)();
    } else {
      observable = Observable(value);
    }
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    assert(
      widget.builder != null || child != null,
      '$runtimeType used outside of Nested must specify a child',
    );

    return ObservableLocatorScope.child(
      create: () => [single<T>(() => observable!.value)],
      builder: widget.builder,
      child: child,
    );
  }
}
