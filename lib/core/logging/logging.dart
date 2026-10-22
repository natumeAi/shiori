import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Routes `package:logging` records to `dart:developer` and captures uncaught
/// Flutter and platform errors. Call once, first thing in `main()`.
void setupLogging() {
  Logger.root.level = kReleaseMode ? Level.INFO : Level.ALL;
  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
  FlutterError.onError = (details) {
    Logger('Flutter')
        .severe(details.exceptionAsString(), details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Logger('Platform').severe('Uncaught error', error, stack);
    return true;
  };
}
