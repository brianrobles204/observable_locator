import 'package:flutter/widgets.dart';
import 'package:nested/nested.dart';
import 'package:observable_locator/observable_locator.dart';

typedef CreateBinders = Iterable<Binder> Function();

/// A scope that provides an [ObservableLocator] to its widget subtree.
///
/// Typically, a root scope is created using the default constructor or
/// [ObservableLocatorScope.value] constructor.
///
/// Then, within the widget tree, the [ObservableLocatorScope.child] constructor
/// is used to create child observable locators that only provide values scoped
/// to a specific widget subtree.
abstract class ObservableLocatorScope extends SingleChildStatefulWidget {
  /// Create a scope that provides an [ObservableLocator] which is managed (i.e.
  /// created and disposed) by this widget.
  ///
  /// Binders for the locator are created once on init using the provided
  /// [create] callback.
  ///
  /// This should typically be used as a root scope and must not shadow an
  /// ancestor observable locator scope.
  factory ObservableLocatorScope({
    Key? key,
    required CreateBinders create,
    TransitionBuilder? builder,
    Widget? child,
  }) =>
      _ManagedObservableLocatorScope(
        key: key,
        create: create,
        builder: builder,
        child: child,
      );

  /// Create a scope that provides the given [ObservableLocator].
  ///
  /// Note that the widget will still dispose the locator when the widget's
  /// state is itself disposed.
  ///
  /// This should typically be used as a root scope and must not shadow an
  /// ancestor observable locator scope.
  factory ObservableLocatorScope.value(
    ObservableLocator locator, {
    Key? key,
    TransitionBuilder? builder,
    Widget? child,
  }) =>
      _ValueObservableLocatorScope(
        key: key,
        locator: locator,
        builder: builder,
        child: child,
      );

  /// Create a scope that provides a child of an ancestor [ObservableLocator].
  ///
  /// This can be used to scope unique or specific values within an observable
  /// locator to a specific widget subtree.
  ///
  /// There must be an ancestor [ObservableLocatorScope] that provides a
  /// parent locator. Additionally, swapping parent nodes of a branch is not
  /// supported. However, adding or pruning leaves / branches of an observable
  /// locator tree is allowed,
  factory ObservableLocatorScope.child({
    Key? key,
    required CreateBinders create,
    TransitionBuilder? builder,
    Widget? child,
  }) =>
      _ChildObservableLocatorScope(
        key: key,
        create: create,
        builder: builder,
        child: child,
      );

  ObservableLocatorScope._({
    Key? key,
    this.builder,
    Widget? child,
  }) : super(key: key, child: child);

  final TransitionBuilder? builder;

  /// The [ObservableLocator] of the closest [ObservableLocatorScope] that
  /// surrounds the given context.
  ///
  /// If [listen] is true, any changes to the surrounding observable locator
  /// scope will trigger a new [State.build] to widgets, and
  /// [State.didChangeDependencies] for [StatefulWidget].
  ///
  /// `listen: false` is necessary to be able to call this method inside of
  /// [State.initState].
  static ObservableLocator of(BuildContext context, {bool listen = true}) {
    assert(_debugCheckHasLocator(context));

    final element = context.getElementForInheritedWidgetOfExactType<
        _InheritedObservableLocatorScope>()!;

    if (listen) {
      context.dependOnInheritedElement(element);
    }

    return (element.widget as _InheritedObservableLocatorScope).locator;
  }

  @protected
  ObservableLocator createLocator(BuildContext context);

  @protected
  ObservableLocator updateLocator(
    BuildContext context,
    ObservableLocator locator,
  );

  @protected
  void disposeLocator(BuildContext context, ObservableLocator locator);

  @override
  _ObservableLocatorScopeState createState() => _ObservableLocatorScopeState();
}

mixin _DisposeLocatorMixin on ObservableLocatorScope {
  @override
  void disposeLocator(BuildContext context, ObservableLocator locator) {
    locator.dispose();
  }
}

class _ManagedObservableLocatorScope extends ObservableLocatorScope
    with _DisposeLocatorMixin {
  _ManagedObservableLocatorScope({
    Key? key,
    required this.create,
    TransitionBuilder? builder,
    Widget? child,
  }) : super._(
          key: key,
          builder: builder,
          child: child,
        );

  final CreateBinders create;

  @override
  ObservableLocator createLocator(BuildContext context) {
    assert(_debugCheckIsShadowing(context));
    final binders = create();
    final locator = ObservableLocator(binders);
    return locator;
  }

  @override
  ObservableLocator updateLocator(
    BuildContext context,
    ObservableLocator locator,
  ) {
    assert(_debugCheckIsShadowing(context));
    return locator;
  }
}

class _ValueObservableLocatorScope extends ObservableLocatorScope
    with _DisposeLocatorMixin {
  _ValueObservableLocatorScope({
    Key? key,
    required this.locator,
    TransitionBuilder? builder,
    Widget? child,
  }) : super._(
          key: key,
          builder: builder,
          child: child,
        );

  final ObservableLocator locator;

  @override
  ObservableLocator createLocator(BuildContext context) {
    assert(_debugCheckIsShadowing(context));
    return locator;
  }

  @override
  ObservableLocator updateLocator(
    BuildContext context,
    ObservableLocator locator,
  ) {
    assert(_debugCheckIsShadowing(context));
    assert(() {
      if (locator != this.locator) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
              'The given locator $locator does not match the original locator.'),
          ErrorDescription(
            'The locator value cannot be changed. The given locator $locator '
            'should match the original locator ${this.locator}',
          ),
        ]);
      }
      return true;
    }());

    return locator;
  }
}

class _ChildObservableLocatorScope extends ObservableLocatorScope
    with _DisposeLocatorMixin {
  _ChildObservableLocatorScope({
    Key? key,
    required this.create,
    TransitionBuilder? builder,
    Widget? child,
  }) : super._(
          key: key,
          builder: builder,
          child: child,
        );

  final CreateBinders create;

  @override
  ObservableLocator createLocator(BuildContext context) {
    assert(_debugCheckHasLocator(context));
    final parent = ObservableLocatorScope.of(context, listen: false);
    final binders = create();
    return parent.createChild(binders);
  }

  @override
  ObservableLocator updateLocator(
    BuildContext context,
    ObservableLocator locator,
  ) {
    assert(_debugCheckHasLocator(context));

    final newParent = ObservableLocatorScope.of(context);
    if (newParent != locator.parent) {
      assert(() {
        print('The ObservableLocatorScope above this widget in the widget tree '
            'has a locator@${newParent.hashCode} that does not match this '
            'locator\'s parent@${locator.parent.hashCode}. Recreating the '
            'locator@${locator.hashCode} $locator.');
        return true;
      }());

      return createLocator(context);
    }

    return locator;
  }
}

class _ObservableLocatorScopeState
    extends SingleChildState<ObservableLocatorScope> {
  late ObservableLocator locator;

  @override
  void initState() {
    super.initState();
    locator = widget.createLocator(context);
  }

  @override
  void dispose() {
    super.dispose();
    widget.disposeLocator(context, locator);
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    assert(
      widget.builder != null || child != null,
      '$runtimeType used outside of Nested must specify a child',
    );

    locator = widget.updateLocator(context, locator);

    return _InheritedObservableLocatorScope(
      locator: locator,
      child: widget.builder != null
          ? Builder(
              builder: (context) => widget.builder!(context, child),
            )
          : child!,
    );
  }
}

class _InheritedObservableLocatorScope extends InheritedWidget {
  _InheritedObservableLocatorScope({
    required this.locator,
    required Widget child,
  }) : super(child: child);

  final ObservableLocator locator;

  @override
  bool updateShouldNotify(_InheritedObservableLocatorScope oldWidget) =>
      locator != oldWidget.locator;
}

bool _hasParentLocator(BuildContext context) {
  final element = context.getElementForInheritedWidgetOfExactType<
      _InheritedObservableLocatorScope>();
  return element != null;
}

bool _debugCheckHasLocator(BuildContext context) {
  assert(() {
    if (!_hasParentLocator(context)) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No ObservableLocatorScope found.'),
        ErrorDescription(
          'Could not find a ObservableLocatorScope above this widget.',
        ),
      ]);
    }
    return true;
  }());
  return true;
}

bool _debugCheckIsShadowing(BuildContext context) {
  assert(() {
    if (_hasParentLocator(context)) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
            'This ObservableLocatorScope will shadow an existing locator.'),
        ErrorDescription(
          'An ObservableLocatorScope was found above this widget. '
          'Its locator will be shadowed by this widget.\n'
          'Consider using ObservableLocatorScope.child to create '
          'a child locator that can override the values of the '
          'existing locator',
        ),
      ]);
    }
    return true;
  }());
  return true;
}
