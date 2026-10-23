import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/motion/turn_clock.dart';
import 'package:shiori/features/reader/engine/motion/turn_intent_queue.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';

final class TestTurnClock implements TurnClock {
  @override
  double now = 0;
  final List<void Function()> tasks = [];
  final List<({double time, void Function() call})> timers = [];
  @override
  void post(void Function() task) => tasks.add(task);
  @override
  void Function() after(Duration duration, void Function() task) {
    final timer = (time: now + duration.inMicroseconds / 1000, call: task);
    timers.add(timer);
    return () => timers.remove(timer);
  }

  Future<void> flush([int rounds = 40]) async {
    for (var i = 0; i < rounds; i++) {
      final batch = tasks.toList();
      tasks.clear();
      for (final task in batch) {
        task();
      }
      await Future<void>.value();
    }
  }

  Future<void> advance(double milliseconds) async {
    now += milliseconds;
    for (final timer in timers.toList()) {
      if (timer.time <= now && timers.remove(timer)) timer.call();
    }
    await flush();
  }
}

TurnPosition position(
  int page, {
  String? cfi,
  int section = 0,
  int generation = 0,
  String layout = 'layout',
  int total = 21,
  String? identity,
}) => TurnPosition(
  cfi: cfi ?? 'page-$page',
  layoutKey: layout,
  layoutGeneration: generation,
  sectionIndex: section,
  pageIndex: page,
  pageCount: total,
  pageIdentity: identity ?? '$layout:$section:$page',
  atStart: page == 0,
  atEnd: page == total - 1,
);

final class FakeTurnSession implements TurnSession {
  @override
  TurnSessionState state = TurnSessionState.ready;
  TurnPosition foreground = position(10);
  final List<String> trace = [];
  final List<TurnPosition> origins = [];
  final List<bool> optional = [];
  final Set<TurnDirection> warm = {};
  Future<void>? drainGate;
  Future<PreparedTurn?>? prepareGate;
  Future<TurnNavigation>? navigationGate;
  TurnNavigation? response;
  bool proof = true;
  bool preparationFails = false;
  bool moving = false;
  int live = 0;
  int peak = 0;
  int restores = 0;
  void mark(String operation) {
    expect(ReaderWorkGuard.inCallback, false, reason: operation);
    trace.add(operation);
  }

  PreparedTurn preview(
    TurnPosition origin,
    TurnDirection direction, {
    TurnPosition? target,
  }) {
    live++;
    if (live > peak) peak = live;
    return PreparedTurn(
      origin: origin,
      direction: direction,
      target:
          target ??
          position(
            origin.pageIndex + (direction == TurnDirection.next ? 1 : -1),
          ),
      releaseCallback: () {
        mark('release');
        live--;
      },
    );
  }

  @override
  Future<void> stopAndDrain() async {
    mark('drain');
    await drainGate;
  }

  @override
  void optionalWorkAllowed(bool allowed) {
    mark('optional');
    optional.add(allowed);
  }

  @override
  PreparedTurn? ready(TurnPosition origin, TurnDirection direction) {
    mark('ready');
    return warm.contains(direction) ? preview(origin, direction) : null;
  }

  @override
  Future<PreparedTurn?> prepare(
    TurnPosition origin,
    TurnDirection direction,
  ) async {
    mark('prepare');
    if (preparationFails) return null;
    return prepareGate == null ? preview(origin, direction) : await prepareGate;
  }

  @override
  void bind(TurnPosition origin, List<PreparedTurn> neighbors) {
    mark('bind');
    moving = true;
  }

  @override
  void unbind() {
    mark('unbind');
    moving = false;
  }

  @override
  Future<TurnNavigation> navigate(
    TurnPosition origin,
    TurnDirection direction,
    PreparedTurn? preview,
  ) async {
    mark('navigate');
    origins.add(origin);
    final result = navigationGate != null
        ? await navigationGate!
        : response ??
              TurnNavigation.verified(
                position(
                  origin.pageIndex + (direction == TurnDirection.next ? 1 : -1),
                ),
              );
    if (result.position != null) foreground = result.position!;
    return result;
  }

  @override
  Future<bool> prove(TurnPosition position, {PreparedTurn? preview}) async {
    mark('proof');
    return proof;
  }

  @override
  void accept(TurnPosition position) {
    mark('accept');
  }

  @override
  Future<bool> restore(TurnPosition origin) async {
    mark('restore');
    foreground = origin;
    restores++;
    return true;
  }
}

final class MotionHarness {
  MotionHarness({
    bool reduced = true,
    int initial = 10,
    Future<void> Function()? callback,
  }) {
    session.foreground = position(initial);
    controller = ReaderTurnController(
      session: session,
      initial: position(initial),
      width: 400,
      clock: clock,
      onAccepted: accepted.add,
      onCommitted: callback,
    );
    controller.configure(reducedMotion: reduced);
  }
  final TestTurnClock clock = TestTurnClock();
  final FakeTurnSession session = FakeTurnSession();
  final List<TurnPosition> accepted = [];
  late final ReaderTurnController controller;
  Future<void> settle() async {
    await clock.flush();
    for (var i = 0; i < 5; i++) {
      controller.tick();
      await clock.advance(500);
    }
  }

  Future<TurnResult> turn(TurnDirection direction) async {
    final result = controller.turnPage(direction);
    await settle();
    return result;
  }
}
