/// Compile-time configuration, injected with
/// `--dart-define-from-file=config/<env>.json`.
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const buildId = String.fromEnvironment(
    'BUILD_ID',
    defaultValue: 'local',
  );
  static const buildNumber = String.fromEnvironment('BUILD_NUMBER');
  static const flutterVersion = String.fromEnvironment('FLUTTER_VERSION');
  static const flutterFrameworkRevision = String.fromEnvironment(
    'FLUTTER_FRAMEWORK_REVISION',
  );
  static const flutterEngineRevision = String.fromEnvironment(
    'FLUTTER_ENGINE_REVISION',
  );
}
