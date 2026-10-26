import 'dart:async';

import 'package:flutter/scheduler.dart';

/// Tests provide a deterministic 8333-us frame source. Real runs retain cadence.
abstract interface class ScenarioFrames {
  Future<Duration> next();
}

final class SchedulerScenarioFrames implements ScenarioFrames {
  @override
  Future<Duration> next() {
    final done = Completer<Duration>();
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      done.complete(SchedulerBinding.instance.currentSystemFrameTimeStamp);
    });
    return done.future;
  }
}
