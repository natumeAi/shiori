import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/features/servers/data/health_validation_exception.dart';

part 'server_health.freezed.dart';
part 'server_health.g.dart';

@freezed
abstract class ServerHealth with _$ServerHealth {
  const ServerHealth._();

  const factory ServerHealth({
    required String status,
    required String service,
    required String database,
  }) = _ServerHealth;

  factory ServerHealth.fromJson(Map<String, Object?> json) =>
      _$ServerHealthFromJson(json);

  void requireUsable() {
    if (service != 'epub-reader-server') {
      throw const HealthValidationException(HealthIssue.wrongService);
    }
    if (status != 'ok') {
      throw const HealthValidationException(HealthIssue.malformed);
    }
    if (database == 'unconfigured') {
      throw const HealthValidationException(HealthIssue.databaseUnconfigured);
    }
    if (database != 'ok') {
      throw const HealthValidationException(HealthIssue.malformed);
    }
  }
}
