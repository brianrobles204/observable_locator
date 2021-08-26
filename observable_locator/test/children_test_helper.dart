import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:observable_locator/observable_locator.dart';
import 'package:test/test.dart';

abstract class Vertex {
  Vertex(this.count, {this.value, this.obsValue});

  final int count;
  final String? value;
  final String? obsValue;
  String? mutValue;

  int _disposeCount = 0;
  int get disposeCount => _disposeCount;

  void dispose() => _disposeCount++;
}

class Tail extends Vertex {
  Tail(
    int count, {
    String? value,
    String? obsValue,
  }) : super(count, value: value, obsValue: obsValue);
}

class Head extends Vertex {
  Head(
    int count, {
    String? value,
    String? obsValue,
    this.tailValue,
  }) : super(count, value: value, obsValue: obsValue);

  final String? tailValue;
}

enum _Gen { parent, child }
typedef _HelperMap<T> = Map<_Gen, Map<Type, T>>;
typedef _HelperObsMap<T> = _HelperMap<Observable<T>>;

class ChildrenTestHelper {
  final Map<_Gen, List<Binder>> _binders = {
    _Gen.parent: [],
    _Gen.child: [],
  };

  final _HelperMap<int> _count = {
    _Gen.parent: {
      Head: 0,
      Tail: 0,
    },
    _Gen.child: {
      Head: 0,
      Tail: 0,
    }
  };

  final _HelperObsMap<String> _observables = {
    _Gen.parent: {},
    _Gen.child: {},
  };

  final _HelperObsMap<String> _mutObservables = {
    _Gen.parent: {},
    _Gen.child: {},
  };

  final _HelperObsMap<Object?> _throwables = {
    _Gen.parent: {},
    _Gen.child: {},
  };

  bool _isInit = false;
  ObservableLocator? _parent;
  ObservableLocator? _child;

  int _totalCount = 0;
  int get totalCount => _totalCount;

  int get parentHeadCount => _count[_Gen.parent]![Head]!;
  int get parentTailCount => _count[_Gen.parent]![Tail]!;
  int get childHeadCount => _count[_Gen.child]![Head]!;
  int get childTailCount => _count[_Gen.child]![Tail]!;

  /// Values

  void addParentHeadValue({String? value, bool linkToTail = false}) =>
      _addValue<Head>(value, _Gen.parent, linkToTail: linkToTail);
  void addChildHeadValue({String? value, bool linkToTail = false}) =>
      _addValue<Head>(value, _Gen.child, linkToTail: linkToTail);
  void addParentTailValue({String? value}) =>
      _addValue<Tail>(value, _Gen.parent, linkToTail: false);
  void addChildTailValue({String? value}) =>
      _addValue<Tail>(value, _Gen.child, linkToTail: false);

  /// Futures

  Completer<String> addParentHeadFuture(
          {String? pendingValue, bool linkToTail = false}) =>
      _addFuture<Head>(pendingValue, _Gen.parent, linkToTail: linkToTail);
  Completer<String> addChildHeadFuture(
          {String? pendingValue, bool linkToTail = false}) =>
      _addFuture<Head>(pendingValue, _Gen.child, linkToTail: linkToTail);
  Completer<String> addParentTailFuture({String? pendingValue}) =>
      _addFuture<Tail>(pendingValue, _Gen.parent, linkToTail: false);
  Completer<String> addChildTailFuture({String? pendingValue}) =>
      _addFuture<Tail>(pendingValue, _Gen.child, linkToTail: false);

  /// Streams

  StreamSink<String> addParentHeadStream(
          {String? pendingValue, bool linkToTail = false}) =>
      _addStream<Head>(pendingValue, _Gen.parent, linkToTail: linkToTail);
  StreamSink<String> addChildHeadStream(
          {String? pendingValue, bool linkToTail = false}) =>
      _addStream<Head>(pendingValue, _Gen.child, linkToTail: linkToTail);
  StreamSink<String> addParentTailStream({String? pendingValue}) =>
      _addStream<Tail>(pendingValue, _Gen.parent, linkToTail: false);
  StreamSink<String> addChildTailStream({String? pendingValue}) =>
      _addStream<Tail>(pendingValue, _Gen.child, linkToTail: false);

  /// Observables

  Observable<String> withObservableParentHead(String value) =>
      _observables[_Gen.parent]![Head] ??= Observable<String>(value);

  Observable<String> withObservableChildHead(String value) =>
      _observables[_Gen.child]![Head] ??= Observable<String>(value);

  Observable<String> withObservableParentTail(String value) =>
      _observables[_Gen.parent]![Tail] ??= Observable<String>(value);

  Observable<String> withObservableChildTail(String value) =>
      _observables[_Gen.child]![Tail] ??= Observable<String>(value);

  /// Throwables

  Observable<Object?> withThrowableParentHead(Object? error) =>
      _throwables[_Gen.parent]![Head] ??= Observable<Object?>(error);

  Observable<Object?> withThrowableChildHead(Object? error) =>
      _throwables[_Gen.child]![Head] ??= Observable<Object?>(error);

  Observable<Object?> withThrowableParentTail(Object? error) =>
      _throwables[_Gen.parent]![Tail] ??= Observable<Object?>(error);

  Observable<Object?> withThrowableChildTail(Object? error) =>
      _throwables[_Gen.child]![Tail] ??= Observable<Object?>(error);

  /// Mutables

  Observable<String> withMutableParentHead(String mutValue) =>
      _mutObservables[_Gen.parent]![Head] ??= Observable<String>(mutValue);

  Observable<String> withMutableChildHead(String mutValue) =>
      _mutObservables[_Gen.child]![Head] ??= Observable<String>(mutValue);

  Observable<String> withMutableParentTail(String mutValue) =>
      _mutObservables[_Gen.parent]![Tail] ??= Observable<String>(mutValue);

  Observable<String> withMutableChildTail(String mutValue) =>
      _mutObservables[_Gen.child]![Tail] ??= Observable<String>(mutValue);

  void _increment<T extends Vertex>(_Gen gen) {
    assert(T != Vertex);
    _count[gen]![T] = _count[gen]![T]! + 1;
  }

  Observable<O>? _observableOf<T extends Vertex, O>(
    _HelperObsMap<O> map,
    _Gen gen,
  ) {
    assert(T != Vertex);
    return map[gen]![T];
  }

  Observable<String>? _observableValueOf<T extends Vertex>(
    _HelperObsMap<String> map,
    _Gen gen,
  ) =>
      _observableOf<T, String>(map, gen);

  T _create<T extends Vertex>({
    String? value,
    String? obsValue,
    String? tailValue,
    String? mutValue,
  }) {
    assert(T != Vertex);
    assert(T == Head || tailValue == null);

    final vertex = () {
      if (T == Head) {
        return Head(
          _totalCount++,
          value: value,
          obsValue: obsValue,
          tailValue: tailValue,
        )..mutValue = mutValue;
      } else {
        return Tail(
          _totalCount++,
          value: value,
          obsValue: obsValue,
        )..mutValue = mutValue;
      }
    }();

    return vertex as T;
  }

  void _addValue<T extends Vertex>(
    String? value,
    _Gen gen, {
    required bool linkToTail,
  }) {
    assert(T != Vertex);
    assert(T == Head || !linkToTail);

    _binders[gen]!.add(
      Binder<T>((locator, vertex) {
        _increment<T>(gen);

        final tailValue = linkToTail ? locator.observe<Tail>().value : null;

        final obsValue = _observableValueOf<T>(_observables, gen)?.value;

        final throwable = _observableOf<T, Object?>(_throwables, gen)?.value;
        if (throwable != null) throw throwable;

        final mutObservable = _observableValueOf<T>(_mutObservables, gen);
        if (mutObservable != null && vertex != null) {
          return vertex..mutValue = mutObservable.value;
        }

        return _create<T>(
          value: value,
          obsValue: obsValue,
          tailValue: tailValue,
          mutValue: mutObservable?.value,
        );
      }),
    );
  }

  Completer<String> _addFuture<T extends Vertex>(
    String? pendingValue,
    _Gen gen, {
    required bool linkToTail,
  }) {
    assert(T != Vertex);
    assert(T == Head || !linkToTail);

    final completer = Completer<String>();

    _binders[gen]!.add(
      FutureBinder<T>(
        (locator, vertex, future) {
          _increment<T>(gen);

          final tailValue = linkToTail ? locator.observe<Tail>().value : null;

          final obsValue = _observableValueOf<T>(_observables, gen)?.value;

          final throwable = _observableOf<T, Object?>(_throwables, gen)?.value;
          if (throwable != null) throw throwable;

          final mutObservable = _observableValueOf<T>(_mutObservables, gen);
          if (mutObservable != null && vertex != null && future != null) {
            vertex.mutValue = mutObservable.value;
            return future;
          }

          return completer.future.then(
            (value) => _create<T>(
              value: value,
              obsValue: obsValue,
              tailValue: tailValue,
            ),
          );
        },
        pendingValue:
            pendingValue != null ? _create<T>(value: pendingValue) : null,
      ),
    );

    return completer;
  }

  StreamSink<String> _addStream<T extends Vertex>(
    String? pendingValue,
    _Gen gen, {
    required bool linkToTail,
  }) {
    assert(T != Vertex);
    assert(T == Head || !linkToTail);

    final controller = StreamController<String>.broadcast();

    _binders[gen]!.add(
      StreamBinder<T>(
        (locator, vertex, stream) {
          _increment<T>(gen);

          final tailValue = linkToTail ? locator.observe<Tail>().value : null;

          final obsValue = _observableValueOf<T>(_observables, gen)?.value;

          final throwable = _observableOf<T, Object?>(_throwables, gen)?.value;
          if (throwable != null) throw throwable;

          final mutObservable = _observableValueOf<T>(_mutObservables, gen);
          if (mutObservable != null && vertex != null && stream != null) {
            vertex.mutValue = mutObservable.value;
            return stream;
          }

          return controller.stream.map(
            (value) => _create<T>(
              value: value,
              obsValue: obsValue,
              tailValue: tailValue,
            ),
          );
        },
        pendingValue:
            pendingValue != null ? _create<T>(value: pendingValue) : null,
      ),
    );

    return controller.sink;
  }

  void reset() {
    _binders.values.forEach((list) => list.clear());
    _count.values.forEach((map) => map.updateAll((key, value) => 0));
    _observables.values.forEach((map) => map.clear());
    _mutObservables.values.forEach((map) => map.clear());
    _throwables.values.forEach((map) => map.clear());

    _totalCount = 0;
    _isInit = false;
    _parent = null;
    _child = null;
  }

  void initLocators() {
    assert(!_isInit);
    _isInit = true;

    _parent = ObservableLocator(_binders[_Gen.parent]!);
    _child = _parent!.createChild(_binders[_Gen.child]!);
  }

  Head get parentHead {
    assert(_isInit);
    return _parent!.observe<Head>();
  }

  Head get childHead {
    assert(_isInit);
    return _child!.observe<Head>();
  }

  Tail get parentTail {
    assert(_isInit);
    return _parent!.observe<Tail>();
  }

  Tail get childTail {
    assert(_isInit);
    return _child!.observe<Tail>();
  }

  Iterable<T Function()> allLocatorsObserve<T>() {
    assert(_isInit);
    return [
      () => _parent!.observe<T>(),
      () => _child!.observe<T>(),
    ];
  }

  void dispose() {
    _parent?.dispose();
  }
}

Matcher isHeadWith({
  int? count,
  String? value,
  String? obsValue,
  String? mutValue,
  String? tailValue,
  int? disposeCount,
}) =>
    _isVertexWith<Head>(
        count: count,
        value: value,
        obsValue: obsValue,
        mutValue: mutValue,
        disposeCount: disposeCount,
        otherChecks: (head) => tailValue == null || tailValue == head.tailValue,
        otherDescriptions: [
          if (tailValue != null) 'has tailValue of $tailValue'
        ]);

Matcher isTailWith<T>({
  int? count,
  String? value,
  String? obsValue,
  String? mutValue,
  int? disposeCount,
}) =>
    _isVertexWith<Tail>(
      count: count,
      value: value,
      obsValue: obsValue,
      mutValue: mutValue,
      disposeCount: disposeCount,
    );

Matcher _isVertexWith<T extends Vertex>({
  int? count,
  String? value,
  String? obsValue,
  String? mutValue,
  int? disposeCount,
  bool Function(T value)? otherChecks,
  Iterable<String>? otherDescriptions,
}) =>
    predicate<T>(
      (vertex) {
        final countIsValid = count == null || vertex.count == count;
        final valueIsValid = value == null || vertex.value == value;
        final obsValueIsValid = obsValue == null || vertex.obsValue == obsValue;
        final mutValueIsValid = mutValue == null || vertex.mutValue == mutValue;
        final disposeIsValid =
            disposeCount == null || vertex.disposeCount == disposeCount;

        return countIsValid &&
            valueIsValid &&
            obsValueIsValid &&
            mutValueIsValid &&
            disposeIsValid &&
            (otherChecks?.call(vertex) ?? true);
      },
      [
        if (count != null) 'has count of $count',
        if (value != null) 'has value of $value',
        if (obsValue != null) 'has obsValue of $obsValue',
        if (mutValue != null) 'has mutValue of $mutValue',
        if (disposeCount != null) 'has disposeCount of $disposeCount',
        ...?otherDescriptions,
      ].join(', '),
    );
