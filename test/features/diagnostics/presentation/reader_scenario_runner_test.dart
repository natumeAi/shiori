import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_scenario_runner.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/scenario_frames.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/scenario_target.dart';

void main() {
  for (final (id, downs, moves) in [
    ('R01', 80, 0),
    ('R02', 5, 216),
    ('R03', 1, 30),
    ('R04', 16, 0),
    ('R05', 12, 0),
    ('R06', 3, 0),
    ('R07', 9, 0),
    ('R08', 6, 0),
    ('R09', 3, 1),
    ('R10', 100, 0),
    ('R11', 0, 0),
  ]) {
    test(
      '$id pointer counts, strictly frame-driven cadence and control calls',
      () async {
        final frames = _Frames();
        final target = _Target();
        final events = <PointerEvent>[];
        final runner = ReaderScenarioRunner(
          target: target,
          readerRect: () => const Rect.fromLTWH(10, 20, 430, 800),
          frames: frames,
          inject: events.add,
        );
        await runner.run(id);
        expect(events.whereType<PointerDownEvent>().length, downs);
        expect(events.whereType<PointerUpEvent>().length, downs);
        expect(events.whereType<PointerMoveEvent>().length, moves);
        for (var i = 1; i < events.length; i++) {
          final delta = events[i].timeStamp - events[i - 1].timeStamp;
          expect(delta.inMicroseconds, greaterThanOrEqualTo(8333));
          expect(delta.inMicroseconds % 8333, 0);
        }
        for (final event in events) {
          expect(event.kind, PointerDeviceKind.touch);
          expect(event.position.dy, 420);
          expect(event.position.dx, inInclusiveRange(30, 420));
        }
        if (id == 'R02') {
          expect(
            target.calls,
            containsAllInOrder([
              'jump:1:0:false',
              'jump:0:0:false',
              'jump:2:-1:false',
            ]),
          );
          final moved = events.whereType<PointerMoveEvent>().toList();
          // Slow movement < commit velocity; flick is comfortably above 0.45 px/ms.
          expect(moved[1].delta.dx.abs() / 8.333, lessThan(.45));
          expect(moved[91].delta.dx.abs() / 8.333, greaterThan(.45));
        }
        if (id == 'R03') {
          expect(target.calls, containsAllInOrder(['hold', 'release']));
        }
        if (id == 'R04') {
          expect(
            target.calls.lastWhere((v) => v.startsWith('jump')),
            'jump:2:0:false',
          );
        }
        if (id == 'R06') expect(target.calls, contains('longParagraph'));
        if (id == 'R08') expect(target.calls, contains('largeText'));
        if (id == 'R09') {
          expect(target.calls.where((v) => v == 'suspend').length, 2);
        }
        if (id == 'R10') {
          expect(
            target.calls.where((v) => v == 'snapshot').length,
            greaterThanOrEqualTo(113),
          );
        }
      },
    );
  }
  test(
    'cancellation releases held work and never injects after pending frame',
    () async {
      final frame = Completer<Duration>();
      final events = <PointerEvent>[];
      final target = _Target();
      final runner = ReaderScenarioRunner(
        target: target,
        readerRect: () => const Rect.fromLTWH(0, 0, 430, 800),
        frames: _PendingFrame(frame),
        inject: events.add,
      );
      final run = runner.run('R01');
      runner.cancel();
      frame.complete(const Duration(microseconds: 8333));
      await expectLater(run, throwsA(isA<ScenarioCancelled>()));
      expect(events, isEmpty);
      expect(target.calls, contains('release'));
    },
  );
  test(
    '60 Hz input remains one move per actual frame without catch-up',
    () async {
      final events = <PointerEvent>[];
      final runner = ReaderScenarioRunner(
        target: _Target(),
        readerRect: () => const Rect.fromLTWH(0, 0, 430, 800),
        frames: _Frames(period: 16667),
        inject: events.add,
      );
      await runner.drag(.78, .22, 30);
      final moves = events.whereType<PointerMoveEvent>().toList();
      for (var i = 1; i < moves.length; i++) {
        expect(
          (moves[i].timeStamp - moves[i - 1].timeStamp).inMicroseconds,
          16667,
        );
      }
    },
  );
}

final class _Frames implements ScenarioFrames {
  _Frames({this.period = 8333});
  final int period;
  int tick = 0;
  @override
  Future<Duration> next() async => Duration(microseconds: ++tick * period);
}

final class _PendingFrame implements ScenarioFrames {
  _PendingFrame(this.frame);
  final Completer<Duration> frame;
  @override
  Future<Duration> next() => frame.future;
}

final class _Target implements ScenarioTarget {
  final calls = <String>[];
  @override
  int get sectionCount => 3;
  @override
  int get pageCount => 4;
  @override
  bool get atEnd => false;
  @override
  Future<void> jump(int section, {int page = 0, bool cold = false}) async =>
      calls.add('jump:$section:$page:$cold');
  @override
  Future<void> largeText() async => calls.add('largeText');
  @override
  Future<void> longParagraph() async => calls.add('longParagraph');
  @override
  Future<void> warm() async => calls.add('warm');
  @override
  void holdPreparation() => calls.add('hold');
  @override
  void releasePreparation() => calls.add('release');
  @override
  void suspend() => calls.add('suspend');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  void snapshot() => calls.add('snapshot');
}
