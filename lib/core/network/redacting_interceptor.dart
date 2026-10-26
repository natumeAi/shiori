import 'package:dio/dio.dart';
import 'package:shiori/core/network/redacted_request_log.dart';
import 'package:shiori/core/network/server_route.dart';

/// Records header latency for each hop; never logs path, headers or body.
final class RedactingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra.putIfAbsent(
      RedactedRequestLog.extraKey,
      () => RedactedRequestLog(ServerRoute.unknown),
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    RedactedRequestLog.from(response.requestOptions)
        ?.write(response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type != DioExceptionType.cancel) {
      RedactedRequestLog.from(err.requestOptions)
          ?.write(err.response?.statusCode, failed: true);
    }
    handler.next(err);
  }
}
