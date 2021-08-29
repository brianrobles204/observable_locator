import 'package:flutter/widgets.dart' hide Action;
import 'package:mobx/mobx.dart';
import 'package:nested/nested.dart';
import 'package:observable_locator/observable_locator.dart';

import 'observable_locator_scope.dart';
import 'bind_inherited.dart';

class UpdateBuilder<T> {
  const UpdateBuilder(this.update);

  final Update<T> update;

  _UpdateState<T> _toState() => _UpdateState(update);
}

class _UpdateState<T> {
  _UpdateState(this._update);

  final Update<T> _update;

  Observable<T>? _observable;

  Binder<T> createBinder() => single<T>(() => _observable!.value);

  void update(BuildContext context) {
    final newValue = _update(context);
    if (_observable != null) {
      _observable!.value = newValue;
    } else {
      _observable = Observable<T>(newValue);
    }
  }
}

typedef Init<T> = T Function();

/// Binds multiple inherited widgets to the surrounding
/// [ObservableLocatorScope]. The values of these observables can be created and
/// updated by relying on Flutter's [InheritedWidget] reactivity system.
///
/// The exposed value for a chosen type is created by providing an
/// [UpdateBuilder]. Whenever a dependency of the value updates, the update
/// builder will also be called again to update the value itself.
///
/// If the value does not depend on a [BuildContext], consider using
/// [BindValue] instead.
class BindMultipleInherited extends SingleChildStatefulWidget {
  /// Binds multiple inherited widgets using the provided update builders.
  ///
  /// Note that [initUpdateBuilders] is only called once when the widget
  /// is initialized. The initial update builders are then used to create and
  /// update the observable values.
  ///
  /// It is recommended to avoid conditionally including update builders in the
  /// list.
  const BindMultipleInherited({
    Key? key,
    required this.initUpdateBuilders,
    this.builder,
    Widget? child,
  }) : super(key: key, child: child);

  final Init<List<UpdateBuilder>> initUpdateBuilders;
  final TransitionBuilder? builder;

  @override
  _BindMultipleInheritedState createState() => _BindMultipleInheritedState();
}

class _BindMultipleInheritedState
    extends SingleChildState<BindMultipleInherited> {
  late final List<_UpdateState> updateStates;

  @override
  void initState() {
    super.initState();
    updateStates = widget
        .initUpdateBuilders()
        .map((builder) => builder._toState())
        .toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    runInAction(() {
      for (final updateState in updateStates) {
        updateState.update(context);
      }
    });
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    assert(
      widget.builder != null || child != null,
      '$runtimeType used outside of Nested must specify a child',
    );

    return ObservableLocatorScope.child(
      create: () => updateStates.map((state) => state.createBinder()),
      builder: widget.builder,
      child: child,
    );
  }
}
