import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shiori/core/config/env.dart';
import 'package:shiori/core/diagnostics/diagnostic_record.dart';
import 'package:shiori/core/diagnostics/diagnostic_recorder.dart';
import 'package:shiori/core/diagnostics/diagnostic_summary.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/diagnostic_export_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_sqlite_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_sqlite_result.dart';
import 'package:shiori/features/diagnostics/presentation/probe_storage_controller.dart';
import 'package:shiori/features/diagnostics/presentation/widgets/probe_sqlite_panel.dart';
import 'package:shiori/l10n/l10n.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key, this.frameNumberForTesting});

  // TestPlatformDispatcher exposes frameData without a test setter.
  @visibleForTesting
  final int Function()? frameNumberForTesting;
  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animation;
  final _device = TextEditingController();
  ProbeDeclarations _declarations = const ProbeDeclarations();
  DiagnosticRecord? _record;
  String? _exportPath;
  bool _capturing = false;
  bool _draining = false;
  bool _exporting = false;
  bool _sqliteRunning = false;
  ProbeSqliteResult? _sqliteResult;
  int _sequence = 0;
  int _captureGeneration = 0;
  DiagnosticRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addListener(_motion);
  }

  void _motion() {
    if (_recorder?.phase == CapturePhase.draining) {
      _animation.stop();
      if (!_draining && mounted) setState(() => _draining = true);
      return;
    }
    final recorder = _recorder;
    if (recorder == null || recorder.phase != CapturePhase.recording) return;
    final binding = SchedulerBinding.instance;
    final schedulerUs = binding.currentFrameTimeStamp.inMicroseconds;
    final rawSchedulerUs = binding.currentSystemFrameTimeStamp.inMicroseconds;
    final progress = _animation.value;
    final generation = _captureGeneration;
    // frameData updates after begin-frame/ticker callbacks. Read its identity
    // in this frame's post-frame phase, retaining the ticker's captured values.
    binding.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _captureGeneration ||
          !identical(recorder, _recorder) ||
          recorder.phase != CapturePhase.recording) {
        return;
      }
      recorder.motion(
        frameNumber:
            widget.frameNumberForTesting?.call() ??
            PlatformDispatcher.instance.frameData.frameNumber,
        schedulerUs: schedulerUs,
        rawSchedulerUs: rawSchedulerUs,
        progress: progress,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _capturing) {
      _stop('lifecycle_${state.name}');
    }
  }

  @override
  void didChangeMetrics() {
    if (_capturing) _stop('viewport_changed');
  }

  @override
  void dispose() {
    _captureGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    _device.dispose();
    _recorder?.dispose();
    super.dispose();
  }

  Map<String, Object?> _metadata() {
    final view = View.of(context);
    final logical = view.physicalSize / view.devicePixelRatio;
    Map<String, Object?> define(String value) => {
      'value': value.isEmpty ? null : value,
      'source': value.isEmpty
          ? 'unavailable_compile_time_define'
          : 'compile_time_CI_define',
    };
    // The Flutter tool injects these itself; `--dart-define` cannot set them.
    Map<String, Object?> toolVersion(String? value) => {
      'value': value,
      'source': value == null
          ? 'unavailable_flutter_tool_define'
          : 'flutter_tool_FlutterVersion',
    };
    return {
      'os': Platform.operatingSystemVersion,
      'osSource': 'dart_io_Platform',
      'platform': Platform.operatingSystem,
      'buildMode': kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
      'buildNumber': define(Env.buildNumber),
      'buildNumberInterpretation':
          'CI passes same value to --build-number; no native runtime read',
      'flutterVersion': toolVersion(FlutterVersion.version),
      'frameworkRevision': toolVersion(FlutterVersion.frameworkRevision),
      'engineRevision': toolVersion(FlutterVersion.engineRevision),
      'logicalWidth': logical.width,
      'logicalHeight': logical.height,
      'physicalWidth': view.physicalSize.width,
      'physicalHeight': view.physicalSize.height,
      'dpr': view.devicePixelRatio,
      'orientation': logical.width > logical.height ? 'landscape' : 'portrait',
      'reportedRefreshRate': view.display.refreshRate,
      'refreshRateSource':
          'FlutterView.display metadata; not effective cadence',
      'theme': Theme.of(context).brightness.name,
      'deviceModelSource': _device.text.trim().isEmpty
          ? 'unavailable_not_declared'
          : 'user_provided',
      'settingsSource':
          'user_provided; no automatic power/thermal/limit-frame-rate API',
      'captureMaximumMs': _recorder?.maximumDuration.inMilliseconds,
      'ringCapacity': _recorder?.capacity,
      'drainMs': _recorder?.drainDuration.inMilliseconds,
    };
  }

  void _start() {
    final recorder = ref.read(diagnosticRecorderProvider);
    final exports = ref.read(diagnosticExportRepositoryProvider);
    _recorder = recorder;
    _captureGeneration++;
    final runId =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}-${++_sequence}';
    recorder.start(
      runId: runId,
      declarations: _declarations.copyWith(deviceModel: _device.text.trim()),
      metadata: _metadata(),
    );
    setState(() {
      _capturing = true;
      _draining = false;
      _record = null;
      _exportPath = null;
    });
    // Completion owns drain/export; it checks mounted before touching the UI.
    unawaited(_complete(recorder, exports));
    unawaited(_animation.repeat());
  }

  Future<void> _complete(
    DiagnosticRecorder recorder,
    DiagnosticExportRepository exports,
  ) async {
    final record = await recorder.completed;
    if (!mounted || record == null) return;
    _animation.stop();
    setState(() {
      _capturing = false;
      _draining = false;
      _record = record;
    });
    await _export(record, exports);
  }

  void _stop(String reason) {
    _captureGeneration++;
    _animation.stop();
    if (mounted) setState(() => _draining = true);
    unawaited(_recorder?.stop(reason: reason));
  }

  Future<void> _export(
    DiagnosticRecord record,
    DiagnosticExportRepository exports,
  ) async {
    setState(() => _exporting = true);
    try {
      final latestSqlite =
          _sqliteResult ??
          ProbeSqliteResult.fromMetadata(
            ref
                    .read(probeStorageControllerProvider)
                    .asData
                    ?.value
                    .lastRecord
                    ?.metadata ??
                const {},
          );
      if (latestSqlite case final result?) {
        record = record.copyWith(
          metadata: {
            ...record.metadata,
            ProbeSqliteResult.metadataKey: result.toJson(),
          },
        );
        _record = record;
      }
      final path = await exports.export(record);
      if (!mounted) return;
      setState(() => _exportPath = path);
    } on AppException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.diagnosticsStorageError)),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _runSqlite() async {
    setState(() => _sqliteRunning = true);
    try {
      final result = await ref.read(probeSqliteRepositoryProvider).run();
      if (!mounted) return;
      setState(() {
        _sqliteResult = result;
        _exportPath = null;
      });
    } on AppException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.diagnosticsStorageError)),
      );
    } finally {
      if (mounted) setState(() => _sqliteRunning = false);
    }
  }

  Future<void> _copy(DiagnosticRecord record) async {
    try {
      await Clipboard.setData(
        ClipboardData(
          text: DiagnosticSummary.clipboard(
            record,
            DiagnosticExportRepository.fileName(record),
          ),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.diagnosticsCopied)));
    } on PlatformException catch (e, stack) {
      Logger('DiagnosticsClipboard').warning('Clipboard unavailable', e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.errorUnexpected)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(diagnosticRecorderProvider);
    final storage = ref.watch(probeStorageControllerProvider);
    final l10n = context.l10n;
    final record = _record ?? storage.asData?.value.lastRecord;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.diagnosticsTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MotionSurface(animation: _animation),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    l10n.diagnosticsBuild(
                      Env.buildId,
                      Env.buildNumber.isEmpty
                          ? l10n.diagnosticsUnknown
                          : Env.buildNumber,
                    ),
                  ),
                  Text(
                    l10n.diagnosticsEvidence,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _device,
                    enabled: !_capturing,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: l10n.diagnosticsDeviceModel,
                    ),
                  ),
                  _SettingField(
                    label: l10n.diagnosticsLowPower,
                    value: _declarations.lowPowerMode,
                    enabled: !_capturing,
                    onChanged: (v) => setState(
                      () => _declarations = _declarations.copyWith(
                        lowPowerMode: v,
                      ),
                    ),
                  ),
                  _SettingField(
                    label: l10n.diagnosticsLimitRate,
                    value: _declarations.limitFrameRate,
                    enabled: !_capturing,
                    onChanged: (v) => setState(
                      () => _declarations = _declarations.copyWith(
                        limitFrameRate: v,
                      ),
                    ),
                  ),
                  _SettingField(
                    label: l10n.diagnosticsCharging,
                    value: _declarations.charging,
                    enabled: !_capturing,
                    onChanged: (v) => setState(
                      () => _declarations = _declarations.copyWith(charging: v),
                    ),
                  ),
                  _SettingField(
                    label: l10n.diagnosticsWarm,
                    value: _declarations.warm,
                    enabled: !_capturing,
                    onChanged: (v) => setState(
                      () => _declarations = _declarations.copyWith(warm: v),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _capturing || _exporting || _sqliteRunning
                            ? null
                            : _start,
                        child: Text(l10n.diagnosticsStart),
                      ),
                      OutlinedButton(
                        onPressed: _capturing && !_draining
                            ? () => _stop('user_stop')
                            : null,
                        child: Text(l10n.diagnosticsStop),
                      ),
                    ],
                  ),
                  if (_capturing)
                    Text(
                      _draining
                          ? l10n.diagnosticsDraining
                          : l10n.diagnosticsRecording,
                    ),
                  if (_exporting) Text(l10n.diagnosticsExporting),
                  if (record != null) ...[
                    Text(
                      l10n.diagnosticsResult(
                        record.runId,
                        record.frames.length,
                        record.motion.length,
                      ),
                    ),
                    Text(l10n.diagnosticsPartial),
                    Text(
                      l10n.diagnosticsCadence(
                        _cadenceText(
                          context,
                          record.aggregates['cadencePattern'],
                        ),
                      ),
                    ),
                    if (_exportPath case final path?)
                      SelectableText(l10n.diagnosticsExported(path)),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _capturing || _exporting || _sqliteRunning
                              ? null
                              : () => _export(
                                  record,
                                  ref.read(diagnosticExportRepositoryProvider),
                                ),
                          child: Text(l10n.diagnosticsExport),
                        ),
                        OutlinedButton(
                          onPressed: _capturing || _exporting || _sqliteRunning
                              ? null
                              : () => _copy(record),
                          child: Text(l10n.diagnosticsCopy),
                        ),
                      ],
                    ),
                  ],
                  const Divider(),
                  ProbeSqlitePanel(
                    result:
                        _sqliteResult ??
                        ProbeSqliteResult.fromMetadata(
                          storage.asData?.value.lastRecord?.metadata ??
                              const {},
                        ),
                    running: _sqliteRunning,
                    onRun: _capturing || _exporting || _sqliteRunning
                        ? null
                        : _runSqlite,
                  ),
                  const Divider(),
                  storage.when(
                    data: (saved) => _MarkerEditor(
                      marker: saved.marker,
                      enabled: !_capturing,
                      onSave: (marker) => ref
                          .read(probeStorageControllerProvider.notifier)
                          .saveMarker(marker),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _StorageErrorView(
                      onRetry: () =>
                          ref.invalidate(probeStorageControllerProvider),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cadenceText(BuildContext context, Object? pattern) => switch (pattern) {
  'observed_near_120hz' => context.l10n.diagnosticsCadence120,
  'consistent_with_60hz_system_cap' => context.l10n.diagnosticsCadence60,
  'mixed_cadence_with_over_budget_stages' =>
    context.l10n.diagnosticsCadenceMixed,
  _ => context.l10n.diagnosticsCadenceUnknown,
};

class _StorageErrorView extends StatelessWidget {
  const _StorageErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      spacing: 16,
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        Text(
          context.l10n.diagnosticsStorageError,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        FilledButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
      ],
    ),
  );
}

class _SettingField extends StatelessWidget {
  const _SettingField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final String label;
  final DeclaredSetting value;
  final bool enabled;
  final ValueChanged<DeclaredSetting> onChanged;
  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<DeclaredSetting>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final setting in DeclaredSetting.values)
            DropdownMenuItem(
              value: setting,
              child: Text(switch (setting) {
                DeclaredSetting.on => context.l10n.diagnosticsOn,
                DeclaredSetting.off => context.l10n.diagnosticsOff,
                DeclaredSetting.unknown => context.l10n.diagnosticsUnknown,
              }),
            ),
        ],
        onChanged: enabled
            ? (v) {
                if (v != null) onChanged(v);
              }
            : null,
      );
}

class _MotionSurface extends StatelessWidget {
  const _MotionSurface({required this.animation});
  final Animation<double> animation;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.diagnosticsMotion,
    child: ClipRect(
      child: SizedBox(
        height: 120,
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: animation,
            child: Align(
              alignment: Alignment.centerLeft,
              child: RepaintBoundary(
                child: Container(
                  width: 160,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.auto_stories,
                      size: 48,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
            builder: (context, child) => Transform.translate(
              offset: Offset(
                animation.value *
                    (constraints.maxWidth - 160).clamp(0, double.infinity),
                0,
              ),
              child: Transform.rotate(
                angle: animation.value * .3,
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MarkerEditor extends StatefulWidget {
  const _MarkerEditor({
    required this.marker,
    required this.enabled,
    required this.onSave,
  });
  final String marker;
  final bool enabled;
  final Future<void> Function(String) onSave;
  @override
  State<_MarkerEditor> createState() => _MarkerEditorState();
}

class _MarkerEditorState extends State<_MarkerEditor> {
  late final TextEditingController _text;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.marker);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_text.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.diagnosticsMarkerSaved)),
      );
    } on AppException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.diagnosticsStorageError)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      Text(context.l10n.diagnosticsMarkerHelp),
      TextField(
        controller: _text,
        enabled: widget.enabled && !_saving,
        maxLength: 256,
        inputFormatters: [
          TextInputFormatter.withFunction(
            (oldValue, newValue) =>
                newValue.text.length <= 256 ? newValue : oldValue,
          ),
        ],
        decoration: InputDecoration(labelText: context.l10n.diagnosticsMarker),
      ),
      OutlinedButton(
        onPressed: widget.enabled && !_saving ? _save : null,
        child: Text(context.l10n.diagnosticsSaveMarker),
      ),
    ],
  );
}
