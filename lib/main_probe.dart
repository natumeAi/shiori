import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/probe_app.dart';
import 'package:shiori/core/logging/logging.dart';
import 'package:shiori/core/network/retry_policy.dart';

void main() {
  setupLogging();
  runApp(const ProviderScope(retry: retryNetworkErrors, child: ProbeApp()));
}
