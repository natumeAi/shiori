import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:shiori/core/network/server_route.dart';

/// Safe metadata shared with guardDio. No raw exception is attached to a log.
final class RedactedRequestLog {
  RedactedRequestLog(this.route) : _watch = Stopwatch()..start();

  static const extraKey = 'shiori.redactedRequestLog';
  final ServerRoute route;
  final Stopwatch _watch;
  bool _written = false;

  void write(int? status, {bool failed = false}) {
    if (_written) return;
    _written = true;
    Logger('Http').log(
      failed ? Level.WARNING : Level.FINE,
      'GET ${route.template} status=${status ?? '-'} '
      'elapsedMs=${_watch.elapsedMilliseconds}',
    );
  }

  static RedactedRequestLog? from(RequestOptions options) {
    final value = options.extra[extraKey];
    return value is RedactedRequestLog ? value : null;
  }
}
