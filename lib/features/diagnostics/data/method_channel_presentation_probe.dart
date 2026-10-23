import 'package:flutter/services.dart';
import 'package:shiori/features/diagnostics/data/presentation_payload.dart';
import 'package:shiori/features/diagnostics/data/presentation_probe.dart';

/// Constructed only by the reader probe. Construction performs no native work.
final class MethodChannelPresentationProbe implements PresentationProbe {
  MethodChannelPresentationProbe({
    this.channel = const MethodChannel(channelName),
  });

  static const channelName = 'io.github.natumeai.shiori/presentation_probe';
  final MethodChannel channel;
  UnavailablePresentationProbe? _fallback;
  PresentationReport? _installation, _last;
  PresentationMode _mode = PresentationMode.inventory;
  bool _disposed = false, _started = false;
  bool _nativeMayBeInstalled = false;

  void _checkAlive() {
    if (_disposed) throw StateError('Presentation probe disposed');
  }

  Future<Object?> _call(String method, [Map<String, Object?>? args]) async {
    try {
      return await channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      _fallback = UnavailablePresentationProbe(
        reason: 'missing_plugin_$method',
      );
    } on PlatformException {
      // Messages/details are deliberately excluded from privacy-safe exports.
      _fallback = UnavailablePresentationProbe(
        reason: 'platform_error_$method',
      );
      if (method == 'start' || method == 'stop') await _disableNative();
    }
    return null;
  }

  Future<void> _disableNative() async {
    try {
      await channel.invokeMethod<void>('dispose');
    } on MissingPluginException {
      // Unsupported platform: there is no native hook owner to disable.
    } on PlatformException {
      // Preserve the original omission; cleanup can only be best effort when
      // the native channel itself is failing.
    }
  }

  Future<PresentationReport> _unavailable() async {
    final report = await _fallback!.stop();
    return PresentationReport(
      available: false,
      evidence: _mode.evidence,
      omission: report.omission,
    );
  }

  @override
  Future<PresentationReport> install() async {
    _checkAlive();
    if (_installation case final report?) return report;
    _nativeMayBeInstalled = true;
    final value = await _call('install');
    return _installation = _fallback != null
        ? await _unavailable()
        : PresentationPayload.parse(value, PresentationMode.inventory);
  }

  @override
  Future<void> start({
    required String runId,
    required PresentationMode mode,
  }) async {
    _checkAlive();
    if (_installation == null || _started) {
      throw StateError('Install before starting an idle presentation probe');
    }
    if (runId.isEmpty) throw ArgumentError.value(runId, 'runId');
    _mode = mode;
    _last = null;
    if (_fallback == null) {
      await _call('start', {'runId': runId, 'mode': mode.name});
    } else {
      await _fallback!.start(runId: runId, mode: mode);
    }
    _started = true;
  }

  @override
  Future<PresentationReport> stop() async {
    _checkAlive();
    if (_last case final report?) return report;
    if (!_started) throw StateError('Presentation probe is not running');
    try {
      final value = _fallback == null ? await _call('stop') : null;
      return _last = _fallback != null
          ? await _unavailable()
          : PresentationPayload.parse(value, _mode);
    } finally {
      _started = false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_nativeMayBeInstalled) await _disableNative();
    await _fallback?.dispose();
  }
}
