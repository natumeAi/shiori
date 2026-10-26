import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/guard_dio.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/servers/data/health_validation_exception.dart';
import 'package:shiori/features/servers/data/models/server_health.dart';

/// Candidate-only repository; never reads active-session providers.
final class HealthRepository {
  const HealthRepository(this._transport);

  final SessionTransport _transport;

  Future<ServerHealth> validate() async {
    try {
      return await guardDio(() async {
        final response = await _transport.getJson(['api', 'health']);
        final body = response.body;
        if (body is! Map<String, Object?>) {
          throw const HealthValidationException(HealthIssue.malformed);
        }
        final health = ServerHealth.fromJson(body);
        health.requireUsable();
        return health;
      });
    } on ParseException {
      throw const HealthValidationException(HealthIssue.malformed);
    } on ServerException catch (error) {
      // Failed DB checks throw HTTP 500; database:"error" is not a wire value.
      if (error.statusCode == 500) {
        throw const HealthValidationException(HealthIssue.databaseFailed);
      }
      rethrow;
    }
  }
}
