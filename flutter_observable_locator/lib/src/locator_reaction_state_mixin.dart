import 'package:flutter/widgets.dart';
import 'package:flutter_observable_locator/flutter_observable_locator.dart';
import 'package:mobx/mobx.dart';
import 'package:observable_locator/observable_locator.dart';

typedef LocatorAutorunFn = void Function(
  Reaction reaction,
  ObservableLocator locator,
);
typedef LocatorReactionFn<T> = T Function(
  Reaction reaction,
  ObservableLocator locator,
);
typedef ReactionEffect<T> = void Function(T value);
typedef OnError = void Function(Object, Reaction);

/// Convenience mixin that provides MobX reaction functions which can rely on
/// the surrounding [ObservableLocatorScope].
///
/// [autorunWithLocator] and [reactionWithLocator] are similar to their
/// [autorun] and [reaction] function counterparts, but these functions will
/// also re-run their callbacks if the [ObservableLocatorScope] provides a
/// different locator. This avoids reactions that listen to stale locators.
///
/// Furthermore, reactions made with these functions are also automatically
/// disposed when the widget is disposed. They can still be disposed early
/// by calling the provided reaction disposer or disposing the reaction in
/// the `fn` callback.
@optionalTypeArgs
mixin LocatorReactionStateMixin<T extends StatefulWidget> on State<T> {
  ObservableLocator? _locator;
  Set<_ReactionDef> _reactions = {};

  /// Executes the specified [fn], whenever the dependent observables change.
  /// Also executes [fn] when the observable locator scope changes.
  ///
  /// The reaction will be disposed automatically when the widget state is
  /// disposed.
  ///
  /// Returns a disposer that can be used to dispose the autorun early.
  ///
  /// This function can safely be called in [initState]. If called in a method
  /// that is run multiple times such as [didUpdateWidget], it is the
  /// responsibility of the caller to dispose of older stale reactions.
  ReactionDisposer autorunWithLocator(
    LocatorAutorunFn fn, {
    String? name,
    int? delay,
    ReactiveContext? context,
    OnError? onError,
  }) {
    final reaction = _AutorunDef(fn, name, delay, context, onError, (reaction) {
      _reactions.remove(reaction);
    });
    _addReaction(reaction);
    return reaction.dispose;
  }

  /// Executes the [fn] function and tracks the observables used in it,
  /// re-executing whenever the dependent observables change or the observable
  /// locator scope changes. If the `T` value returned by [fn] is different,
  /// the [effect] function is executed.
  ///
  /// The reaction will be disposed automatically when the widget state is
  /// disposed.
  ///
  /// Returns a disposer that can be used to dispose the reaction early.
  ///
  /// *Note*: Only the [fn] function is tracked and not the [effect].
  ///
  /// This function can safely be called in [initState]. If called in a method
  /// that is run multiple times such as [didUpdateWidget], it is the
  /// responsibility of the caller to dispose of older stale reactions.
  ReactionDisposer reactionWithLocator<T>(
    LocatorReactionFn<T> fn,
    ReactionEffect<T> effect, {
    String? name,
    int? delay,
    bool? fireImmediately,
    EqualityComparer<T>? equals,
    ReactiveContext? context,
    OnError? onError,
  }) {
    final reaction = _ReactionFnDef(
        fn, effect, name, delay, fireImmediately, equals, context, onError,
        (reaction) {
      _reactions.remove(reaction);
    });
    _addReaction(reaction);
    return reaction.dispose;
  }

  void _addReaction(_ReactionDef reaction) {
    final currentLocator = ObservableLocatorScope.of(context, listen: false);
    if (currentLocator == _locator) {
      // New reaction after didChangeDependencies() was called. Set-up reaction.
      // Otherwise, if locators are different, it should be handled by
      // didChangeDependencies() later.
      reaction.update(currentLocator);
    }
    _reactions.add(reaction);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newLocator = ObservableLocatorScope.of(context);
    if (newLocator != _locator) {
      _locator = newLocator;
      for (final reaction in Set.of(_reactions)) {
        reaction.update(newLocator);
      }
    }
  }

  @override
  void dispose() {
    for (final reaction in Set.of(_reactions)) {
      reaction.dispose();
    }
    super.dispose();
  }
}

typedef _OnDispose = void Function(_ReactionDef reaction);

abstract class _ReactionDef {
  _ReactionDef(this._onDisposeDef);

  final _OnDispose _onDisposeDef;

  ReactionDisposer? _disposeCurrent;

  void update(ObservableLocator locator) {
    _disposeCurrent?.call();
    _disposeCurrent = createReaction(locator);
  }

  @protected
  late final VoidCallback onDispose = () => _onDisposeDef(this);

  @protected
  ReactionDisposer createReaction(ObservableLocator locator);

  late final ReactionDisposer dispose = _ReactionDisposerWrapper(
    getReaction: () => _disposeCurrent!.reaction,
    onDispose: () {
      _disposeCurrent?.call();
      onDispose();
    },
  );
}

class _AutorunDef extends _ReactionDef {
  _AutorunDef(
    this.fn,
    this.name,
    this.delay,
    this.context,
    this.onError,
    _OnDispose onDispose,
  ) : super(onDispose);

  final LocatorAutorunFn fn;
  final String? name;
  final int? delay;
  final ReactiveContext? context;
  final OnError? onError;

  @override
  ReactionDisposer createReaction(ObservableLocator locator) => autorun(
        (reaction) => fn(_ReactionWrapper(reaction, onDispose), locator),
        name: name,
        delay: delay,
        context: context,
        onError: onError,
      );
}

class _ReactionFnDef<T> extends _ReactionDef {
  _ReactionFnDef(
      this.fn,
      this.effect,
      this.name,
      this.delay,
      this.fireImmediately,
      this.equals,
      this.context,
      this.onError,
      _OnDispose onDispose)
      : super(onDispose);

  final LocatorReactionFn<T> fn;
  final ReactionEffect<T> effect;
  final String? name;
  final int? delay;
  final bool? fireImmediately;
  final EqualityComparer<T>? equals;
  final ReactiveContext? context;
  final OnError? onError;

  @override
  ReactionDisposer createReaction(ObservableLocator locator) => reaction<T>(
        (reaction) => fn(_ReactionWrapper(reaction, onDispose), locator),
        effect,
        name: name,
        delay: delay,
        fireImmediately: fireImmediately,
        equals: equals,
        context: context,
        onError: onError,
      );
}

typedef _ReactionCallback = Reaction Function();

class _ReactionDisposerWrapper implements ReactionDisposer {
  _ReactionDisposerWrapper({
    required _ReactionCallback getReaction,
    required this.onDispose,
  }) : _getReaction = getReaction;

  final _ReactionCallback _getReaction;
  final VoidCallback onDispose;

  @override
  Reaction get reaction => _getReaction();

  @override
  void call() {
    onDispose();
  }
}

class _ReactionWrapper implements Reaction {
  _ReactionWrapper(this.parent, this.onDispose);

  final Reaction parent;
  final VoidCallback onDispose;

  @override
  String get name => parent.name;

  @override
  MobXCaughtException? get errorValue => parent.errorValue;

  @override
  bool get isDisposed => parent.isDisposed;

  @override
  void dispose() {
    parent.dispose();
    onDispose();
  }
}
