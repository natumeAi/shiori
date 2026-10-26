import 'package:flutter/scheduler.dart';

abstract interface class FrameSource {
  void start(void Function(List<FrameTiming>) onTimings);
  void stop();
}
