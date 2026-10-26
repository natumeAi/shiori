import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';
import 'package:shiori/features/reader/engine/surface/surface_frame.dart';

/// Reader-local transform state. Page widgets and pictures stay stable per frame.
final class PreparedReader extends StatefulWidget {
  const PreparedReader({
    super.key,
    required this.controller,
    required this.session,
    this.closeOnDispose = true,
    this.onPageBuild,
    this.frameNumberForTesting,
  });
  final ReaderTurnController controller;
  final PreparedReaderSession session;
  final bool closeOnDispose;
  final VoidCallback? onPageBuild;
  final int Function()? frameNumberForTesting;
  @override
  State<PreparedReader> createState() => _PreparedReaderState();
}

final class _PreparedReaderState extends State<PreparedReader>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ValueNotifier<double> _offset = ValueNotifier(0);
  late final Ticker _ticker;
  VoidCallback? _oldChanged;
  void Function(double)? _oldOffset;
  int? _pointer;
  bool _suspended = false;
  ReaderTurnController get controller => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(
      (_) => ReaderWorkGuard.callback(() {
        controller.tick();
        if (!controller.needsTick) _ticker.stop();
      }),
    );
    _oldChanged = controller.onChanged;
    _oldOffset = controller.onOffset;
    controller.onChanged = _changed;
    controller.onOffset = _move;
  }

  void _move(double value) {
    _offset.value = value;
    _oldOffset?.call(value);
    final sink = controller.timing;
    if (sink is! TurnFrameSink || !controller.needsTick || value == 0) return;
    final frameSink = sink as TurnFrameSink;
    final epoch = frameSink.frameEpoch;
    final input = controller.inputIdentity;
    final binding = SchedulerBinding.instance;
    // Control tasks can rewrite the offset between frames. The next ticker
    // samples that value; scheduler timestamps only exist inside a frame.
    if (binding.schedulerPhase == SchedulerPhase.idle ||
        binding.schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      return;
    }
    final schedulerUs = binding.currentFrameTimeStamp.inMicroseconds;
    final rawUs = binding.currentSystemFrameTimeStamp.inMicroseconds;
    final generation = controller.generation;
    final owner = controller;
    binding.addPostFrameCallback((_) {
      if (!mounted ||
          owner != controller ||
          generation != controller.generation ||
          epoch != frameSink.frameEpoch) {
        return;
      }
      frameSink.submitted(
        frameNumber:
            widget.frameNumberForTesting?.call() ??
            ui.PlatformDispatcher.instance.frameData.frameNumber,
        schedulerUs: schedulerUs,
        rawSchedulerUs: rawUs,
        generation: generation,
        offset: value,
        input: input,
      );
    });
  }

  void _changed() {
    _oldChanged?.call();
    if (mounted && controller.needsTick && !_ticker.isActive) _ticker.start();
  }

  GestureInput _sample(PointerEvent event) => GestureInput(
    event.localPosition.dx,
    event.localPosition.dy,
    event.timeStamp.inMicroseconds / 1000,
  );
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _suspended = true;
      controller.suspend();
    } else if (_suspended) {
      _suspended = false;
      // The controller guards its own generation and closed state; nothing
      // else waits on this restore.
      unawaited(controller.resume());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.configure(
      reducedMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
    );
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        controller.turnPage(TurnDirection.next);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        controller.turnPage(TurnDirection.previous);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => ReaderWorkGuard.callback(() {
        if (_pointer != null) return;
        final admitted = controller.pointerDown(
          event.pointer,
          _sample(event),
          mouse: event.kind == PointerDeviceKind.mouse,
          button: event.buttons == kPrimaryButton ? 0 : 1,
        );
        if (admitted) _pointer = event.pointer;
      }),
      onPointerMove: (event) =>
          controller.pointerMove(event.pointer, _sample(event)),
      onPointerUp: (event) {
        controller.pointerUp(event.pointer, _sample(event));
        if (_pointer == event.pointer) _pointer = null;
      },
      onPointerCancel: (event) {
        controller.pointerCancel(event.pointer);
        if (_pointer == event.pointer) _pointer = null;
      },
      child: ValueListenableBuilder<SurfaceFrame>(
        valueListenable: widget.session.frames,
        builder: (_, frame, _) => ClipRect(
          child: Flow(
            delegate: _PageFlow(
              _offset,
              controller.width,
              controller.readingDirection,
            ),
            children: [
              _PicturePage(
                key: ValueKey(frame.current),
                picture: frame.current.picture,
                onBuild: widget.onPageBuild,
              ),
              if (frame.previous != null)
                _PicturePage(
                  key: ValueKey(frame.previous),
                  picture: frame.previous!.picture,
                  onBuild: widget.onPageBuild,
                )
              else
                const SizedBox.shrink(),
              if (frame.next != null)
                _PicturePage(
                  key: ValueKey(frame.next),
                  picture: frame.next!.picture,
                  onBuild: widget.onPageBuild,
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.onOffset = _oldOffset;
    controller.onChanged = _oldChanged;
    _ticker.dispose();
    _offset.dispose();
    controller.close();
    if (widget.closeOnDispose) widget.session.close();
    super.dispose();
  }
}

final class _PageFlow extends FlowDelegate {
  _PageFlow(this.offset, this.width, this.direction) : super(repaint: offset);
  final ValueNotifier<double> offset;
  final double width;
  final ReadingDirection direction;
  @override
  void paintChildren(FlowPaintingContext context) {
    final sign = direction == ReadingDirection.ltr ? 1.0 : -1.0;
    for (var i = 0; i < context.childCount; i++) {
      final base = i == 1
          ? -width * sign
          : i == 2
          ? width * sign
          : 0.0;
      context.paintChild(
        i,
        transform: Matrix4.translationValues(base + offset.value, 0, 0),
      );
    }
  }

  @override
  bool shouldRepaint(_PageFlow old) =>
      old.offset != offset || old.width != width || old.direction != direction;
}

final class _PicturePage extends StatelessWidget {
  const _PicturePage({super.key, required this.picture, this.onBuild});
  final ui.Picture picture;
  final VoidCallback? onBuild;
  @override
  Widget build(BuildContext context) {
    onBuild?.call();
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PicturePainter(picture),
        child: const SizedBox.expand(),
      ),
    );
  }
}

final class _PicturePainter extends CustomPainter {
  const _PicturePainter(this.picture);
  final ui.Picture picture;
  @override
  void paint(ui.Canvas canvas, ui.Size size) => canvas.drawPicture(picture);
  @override
  bool shouldRepaint(_PicturePainter old) => old.picture != picture;
}
