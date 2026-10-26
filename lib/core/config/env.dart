/// Compile-time build identity. Deployment roots are selected at runtime.
abstract final class Env {
  static const buildId = String.fromEnvironment(
    'BUILD_ID',
    defaultValue: 'local',
  );
  static const buildNumber = String.fromEnvironment('BUILD_NUMBER');
}
