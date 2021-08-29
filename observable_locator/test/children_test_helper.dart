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

  Map<String, String> get descriptions => {
        'count': count.toString(),
        'value': value ?? 'null',
        'obsValue': obsValue ?? 'null',
        'mutValue': mutValue ?? 'null',
        'disposeCount': disposeCount.toString(),
      };

  @override
  String toString() =>
      '$runtimeType {' +
      descriptions.entries.map((e) => e.key + ': ' + e.value).join(', ') +
      '}';
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
    this.tailObsValue,
  }) : super(count, value: value, obsValue: obsValue);

  final String? tailValue;
  final String? tailObsValue;

  @override
  Map<String, String> get descriptions => {
        ...super.descriptions,
        'tailValue': tailValue ?? 'null',
        'tailObsValue': tailObsValue ?? 'null',
      };
}

enum _Gen { parent, child }

class ChildrenTestHelper {
  final Map<_Gen, List<Binder>> _binders = {
    _Gen.parent: [],
    _Gen.child: [],
  };

  final Map<_Gen, Map<Type, int>> _count = {
    _Gen.parent: {
      Head: 0,
      Tail: 0,
    },
    _Gen.child: {
      Head: 0,
      Tail: 0,
    }
  };

  final Map<_Gen, Map<Type, Observable<String>>> _observables = {
    _Gen.parent: {},
    _Gen.child: {},
  };

  final Map<_Gen, Map<Type, Observable<String>>> _mutObservables = {
    _Gen.parent: {},
    _Gen.child: {},
  };

  final Map<_Gen, Map<Type, Observable<Object?>>> _throwables = {
    _Gen.parent: {},
    _Gen.child: {},
  };

  bool _isInit = false;
  ObservableLocator? _parent;
  ObservableLocator? _child;

  /// Number of times a vertex has been created successfully
  int get createCount => _createCount;
  int _createCount = 0;

  /// Counts - number of times the corresponding binder callback has been run

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

  /// Value overrides

  void addParentHeadOverride(Binder<Head> binder) =>
      _binders[_Gen.parent]!.add(binder);
  void addChildHeadOverride(Binder<Head> binder) =>
      _binders[_Gen.child]!.add(binder);
  void addParentTailOverride(Binder<Tail> binder) =>
      _binders[_Gen.parent]!.add(binder);
  void addChildTailOverride(Binder<Tail> binder) =>
      _binders[_Gen.child]!.add(binder);

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

  Observable<String> whereParentHeadObserves(String value) =>
      _observables[_Gen.parent]![Head] ??=
          Observable<String>(value, name: 'Parent-Head-Observable');

  Observable<String> whereChildHeadObserves(String value) =>
      _observables[_Gen.child]![Head] ??=
          Observable<String>(value, name: 'Child-Head-Observable');

  Observable<String> whereParentTailObserves(String value) =>
      _observables[_Gen.parent]![Tail] ??=
          Observable<String>(value, name: 'Parent-Tail-Observable');

  Observable<String> whereChildTailObserves(String value) =>
      _observables[_Gen.child]![Tail] ??=
          Observable<String>(value, name: 'Child-Head-Observable');

  /// Throwables

  Observable<Object?> whereParentHeadThrows(Object? error) =>
      _throwables[_Gen.parent]![Head] ??=
          Observable<Object?>(error, name: 'Parent-Head-Throwable');

  Observable<Object?> whereChildHeadThrows(Object? error) =>
      _throwables[_Gen.child]![Head] ??=
          Observable<Object?>(error, name: 'Child-Head-Throwable');

  Observable<Object?> whereParentTailThrows(Object? error) =>
      _throwables[_Gen.parent]![Tail] ??=
          Observable<Object?>(error, name: 'Parent-Tail-Throwable');

  Observable<Object?> whereChildTailThrows(Object? error) =>
      _throwables[_Gen.child]![Tail] ??=
          Observable<Object?>(error, name: 'Child-Tail-Throwable');

  /// Mutables

  Observable<String> whereParentHeadMutates(String mutValue) =>
      _mutObservables[_Gen.parent]![Head] ??=
          Observable<String>(mutValue, name: 'Parent-Head-Mutable');

  Observable<String> whereChildHeadMutates(String mutValue) =>
      _mutObservables[_Gen.child]![Head] ??=
          Observable<String>(mutValue, name: 'Child-Head-Mutable');

  Observable<String> whereParentTailMutates(String mutValue) =>
      _mutObservables[_Gen.parent]![Tail] ??=
          Observable<String>(mutValue, name: 'Parent-Tail-Mutable');

  Observable<String> whereChildTailMutates(String mutValue) =>
      _mutObservables[_Gen.child]![Tail] ??=
          Observable<String>(mutValue, name: 'Child-Tail-Mutable');

  void _increment<T extends Vertex>(_Gen gen) {
    assert(T != Vertex);
    _count[gen]![T] = _count[gen]![T]! + 1;
  }

  Observable<O>? _observableOf<T extends Vertex, O>(
    Map<_Gen, Map<Type, Observable<O>>> map,
    _Gen gen,
  ) {
    assert(T != Vertex);
    return map[gen]![T];
  }

  Observable<String>? _observableValueOf<T extends Vertex>(
    Map<_Gen, Map<Type, Observable<String>>> map,
    _Gen gen,
  ) =>
      _observableOf<T, String>(map, gen);

  T _create<T extends Vertex>({
    String? value,
    String? obsValue,
    String? tailValue,
    String? tailObsValue,
    String? mutValue,
  }) {
    assert(T != Vertex);
    assert(T == Head || (tailValue == null && tailObsValue == null));

    final vertex = () {
      if (T == Head) {
        return Head(
          _createCount++,
          value: value,
          obsValue: obsValue,
          tailValue: tailValue,
          tailObsValue: tailObsValue,
        )..mutValue = mutValue;
      } else {
        return Tail(
          _createCount++,
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
      bindValue<T>(
        (locator, vertex) {
          _increment<T>(gen);

          final tail = linkToTail ? locator.observe<Tail>() : null;
          final tailValue = tail?.value;
          final tailObsValue = tail?.obsValue;

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
            tailObsValue: tailObsValue,
            mutValue: mutObservable?.value,
          );
        },
        dispose: (vertex) => vertex.dispose(),
      ),
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
      bindFutureValue<T>(
        (locator, vertex, future) {
          _increment<T>(gen);

          final tail = linkToTail ? locator.observe<Tail>() : null;
          final tailValue = tail?.value;
          final tailObsValue = tail?.obsValue;

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
              tailObsValue: tailObsValue,
              mutValue: mutObservable?.value,
            ),
          );
        },
        pendingValue:
            pendingValue != null ? _create<T>(value: pendingValue) : null,
        dispose: (vertex) => vertex.dispose(),
        name: '${gen == _Gen.parent ? 'Parent' : 'Child'}-$Type',
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
      bindStreamValue<T>(
        (locator, vertex, stream) {
          _increment<T>(gen);

          final tail = linkToTail ? locator.observe<Tail>() : null;
          final tailValue = tail?.value;
          final tailObsValue = tail?.obsValue;

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
              tailObsValue: tailObsValue,
              mutValue: mutObservable?.value,
            ),
          );
        },
        pendingValue:
            pendingValue != null ? _create<T>(value: pendingValue) : null,
        dispose: (vertex) => vertex.dispose(),
        name: '${gen == _Gen.parent ? 'Parent' : 'Child'}-$Type',
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

    _createCount = 0;
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

  @override
  String toString() => 'ChildrenTestHelper { '
      'parentHeadCount: $parentHeadCount, '
      'childHeadCount: $childHeadCount, '
      'parentTailCount: $parentTailCount, '
      'childTailCount: $childTailCount, '
      'createCount: $createCount, '
      '}';
}

Matcher isHeadWith({
  int? count,
  String? value,
  String? obsValue,
  String? mutValue,
  String? tailValue,
  String? tailObsValue,
  int? disposeCount,
}) =>
    _isVertexWith<Head>(
      count: count,
      value: value,
      obsValue: obsValue,
      mutValue: mutValue,
      disposeCount: disposeCount,
      otherChecks: (head) {
        final isTailValueValid =
            tailValue == null || tailValue == head.tailValue;
        final isTailObsValueValid =
            tailObsValue == null || tailObsValue == head.tailObsValue;

        return isTailValueValid && isTailObsValueValid;
      },
      otherDescriptions: [
        if (tailValue != null) 'has tailValue of $tailValue',
        if (tailObsValue != null) 'has tailObsValue of $tailObsValue'
      ],
    );

Matcher isNewHeadWith({
  int? count,
  String? value,
  String? obsValue,
  String? mutValue,
  String? tailValue,
  String? tailObsValue,
}) =>
    isHeadWith(
      count: count,
      value: value,
      obsValue: obsValue,
      mutValue: mutValue,
      tailValue: tailValue,
      tailObsValue: tailObsValue,
      disposeCount: 0,
    );

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

Matcher hasCount({
  int? parentHead,
  int? childHead,
  int? parentTail,
  int? childTail,
  int? create,
}) =>
    predicate<ChildrenTestHelper>(
      (helper) {
        final isParentHeadValid =
            parentHead == null || helper.parentHeadCount == parentHead;
        final isChildHeadValid =
            childHead == null || helper.childHeadCount == childHead;
        final isParentTailValid =
            parentTail == null || helper.parentTailCount == parentTail;
        final isChildTailValid =
            childTail == null || helper.childTailCount == childTail;
        final isCreateValid = create == null || helper.createCount == create;

        return isParentHeadValid &&
            isChildHeadValid &&
            isParentTailValid &&
            isChildTailValid &&
            isCreateValid;
      },
      [
        if (parentHead != null) 'has parentHeadCount of $parentHead',
        if (childHead != null) 'has childHeadCount of $childHead',
        if (parentTail != null) 'has parentTailCount of $parentTail',
        if (childTail != null) 'has childTailCount of $childTail',
        if (create != null) 'has createCount of $create',
      ].join(', '),
    );
