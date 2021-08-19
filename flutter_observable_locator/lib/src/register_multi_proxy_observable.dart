import 'package:flutter/widgets.dart' hide Action;
import 'package:mobx/mobx.dart';
import 'package:nested/nested.dart';
import 'package:observable_locator/observable_locator.dart';

import 'observable_locator_scope.dart';
import 'register_proxy_observable.dart';

class UpdateBuilder<T> {
  const UpdateBuilder(this.update);

  final Update<T> update;

  _UpdateState<T> _toState() => _UpdateState(update);
}

class _UpdateState<T> {
  _UpdateState(this._update);

  final Update<T> _update;

  Observable<T>? _observable;
  void update(BuildContext context) {
    final newValue = _update(context);
    if (_observable != null) {
      _observable!.value = newValue;
    } else {
      _observable = Observable<T>(newValue);
    }
  }

  void registerOn(WritableObservableLocator locator) {
    assert(_observable != null);
    locator.register<T>((oldvalue) => _observable!.value);
  }
}

typedef Init<T> = T Function();

/// Registers multiple observables to the surrounding [ObservableLocatorScope].
/// The values of these observables can be created and updated by relying on
/// Flutter's [InheritedWidget] system.
///
/// The exposed value for a chosen type is created by providing an
/// [UpdateBuilder]. Whenever a dependency of the value updates, the update
/// builder will also be called again to update the value itself.
///
/// If the value does not depend on a [BuildContext], consider using
/// [RegisterValue] instead.
class RegisterMultiProxyObservable extends SingleChildStatefulWidget {
  /// Registers multiple observables using the provided update builders.
  ///
  /// Note that [initUpdateBuilders] is only called once when the widget
  /// is initialized. The initial update builders are then used to create and
  /// update the observable values.
  ///
  /// It is recommended to avoid conditionally including update builders in the
  /// list.
  const RegisterMultiProxyObservable({
    Key? key,
    required this.initUpdateBuilders,
    this.builder,
    Widget? child,
  }) : super(key: key, child: child);

  final Init<List<UpdateBuilder>> initUpdateBuilders;
  final TransitionBuilder? builder;

  @override
  _RegisterMultiProxyObservableState createState() =>
      _RegisterMultiProxyObservableState();
}

class _RegisterMultiProxyObservableState
    extends SingleChildState<RegisterMultiProxyObservable> {
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

    Action(() {
      for (final updateState in updateStates) {
        updateState.update(context);
      }
    })();
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    assert(
      widget.builder != null || child != null,
      '$runtimeType used outside of Nested must specify a child',
    );

    return ObservableLocatorScope.child(
      init: (locator) {
        for (final updateState in updateStates) {
          updateState.registerOn(locator);
        }
      },
      builder: widget.builder,
      child: child,
    );
  }
}
