import '../api.dart';
import '../exceptions.dart';

class ObservableLocatorImpl implements ObservableLocator {
  ObservableLocatorImpl([Iterable<Binder> binders = const []])
      : _parent = null {
    _initStates(binders);
  }

  ObservableLocatorImpl._fromParent(this._parent, Iterable<Binder> binders) {
    _initStates(binders);
  }

  final Map<Object, BinderState> _states = {};
  final Map<Object, BinderState> _parentStates = {};

  void _initStates(Iterable<Binder> binders) {
    for (final binder in binders) {
      if (_states.containsKey(binder.key)) {
        throw LocatorValueAlreadyRegisteredException(binder.key);
      }
      _states[binder.key] = binder.createState(this);
    }
  }

  @override
  ObservableLocator? get parent => _parent;
  final ObservableLocatorImpl? _parent;

  @override
  List<ObservableLocator> get children => List.unmodifiable(_children);
  final List<ObservableLocatorImpl> _children = [];

  bool _isDisposed = false;

  BinderState<T>? _stateFor<T>(Object key) {
    final state = _states[key];

    if (state == null) {
      final parentState = _findParentStateFor<T>(key);
      if (parentState != null) _parentStates[key] = parentState.cloneWith(this);

      return _parentStates[key] as BinderState<T>?;
    } else {
      assert(
        state is BinderState<T>,
        'The given key $key does not map to a binder state of type $T',
      );

      return state as BinderState<T>?;
    }
  }

  BinderState<T>? _findParentStateFor<T>(Object key) {
    return (_parent?._states[key] as BinderState<T>?) ??
        _parent?._findParentStateFor(key);
  }

  bool _debugCheckNotDisposed() {
    assert(() {
      if (_isDisposed) {
        throw StateError('The locator $this was '
            'used after being disposed.');
      }
      return true;
    }());
    return true;
  }

  @override
  T observeKey<T>(Object key) {
    assert(_debugCheckNotDisposed());
    final state = _stateFor<T>(key);

    if (state != null) {
      return state.observe();
    } else {
      throw LocatorKeyNotFoundException(key);
    }
  }

  @override
  T? tryObserveKey<T>(Object key) {
    assert(_debugCheckNotDisposed());
    final state = _stateFor<T>(key);

    if (state != null) {
      try {
        return state.tryObserve();
      } catch (e) {
        return null;
      }
    } else {
      assert(() {
        print('WARNING: Tried to observe $key '
            'but no binder was found in $this.');
        return true;
      }());
      return null;
    }
  }

  @override
  ObservableLocator createChild([Iterable<Binder> binders = const []]) {
    assert(_debugCheckNotDisposed());

    final child = ObservableLocatorImpl._fromParent(this, binders);
    _children.add(child);

    return child;
  }

  void _notifyChildDisposed(ObservableLocatorImpl child) {
    if (!_isDisposed) {
      assert(_children.contains(child));
      _children.remove(child);
    }
  }

  @override
  void dispose() {
    assert(_debugCheckNotDisposed());

    final states = List<BinderState>.from(_states.values);
    states.forEach((state) => state.dispose());

    final parentStates = List<BinderState>.from(_parentStates.values);
    parentStates.forEach((parentState) => parentState.dispose());

    final children = List<ObservableLocatorImpl>.from(_children);
    children.forEach((child) => child.dispose());
    _parent?._notifyChildDisposed(this);

    _states.clear();
    _children.clear();
    _isDisposed = true;
  }

  @override
  String toString() {
    return [
      'ObservableLocatorImpl { ',
      if (_parent != null) 'with parent, ',
      '${_children.length} children, ',
      '${_states.length} registered values ',
      '}'
    ].join();
  }
}
