import 'package:flutter/scheduler.dart';
import 'package:shiori/core/diagnostics/frame_source.dart';

class SchedulerFrameSource implements FrameSource {
  void Function(List<FrameTiming>)? _callback;

  @override
  void start(void Function(List<FrameTiming>) onTimings) {
    stop();
    _callback = onTimings;
    SchedulerBinding.instance.addTimingsCallback(onTimings);
  }

  @override
  void stop() {
    final callback = _callback;
    if (callback != null) {
      SchedulerBinding.instance.removeTimingsCallback(callback);
      _callback = null;
    }
  }
}
