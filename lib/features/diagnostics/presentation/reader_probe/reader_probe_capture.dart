part of 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_screen.dart';

extension _ReaderProbeCapture on _ReaderProbeScreenState {
  Map<String, Object?> _metadata() {
    final view = View.of(context);
    return {
      'platform': Platform.operatingSystem,
      'os': Platform.operatingSystemVersion,
      'buildNumber': Env.buildNumber.isEmpty ? null : Env.buildNumber,
      'flutterVersion': FlutterVersion.version,
      'frameworkRevision': FlutterVersion.frameworkRevision,
      'engineRevision': FlutterVersion.engineRevision,
      'buildMode': kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
      'logicalWidth': _reader.width,
      'logicalHeight': _reader.height,
      'dpr': view.devicePixelRatio,
      'physicalWidth': view.physicalSize.width,
      'physicalHeight': view.physicalSize.height,
      'reportedRefreshRate': view.display.refreshRate,
      'refreshRateSource': 'display metadata; not effective cadence',
      'settings': _reader.settings.toJson(),
      'reducedMotion': _reader.reducedMotion,
      'systemReducedMotion': MediaQuery.disableAnimationsOf(context),
      'ringCapacity': _recorder.events.capacity,
      'engineRingCapacity': _recorder.engine.capacity,
      'maximumCaptureMs': _recorder.engine.maximumDuration.inMilliseconds,
      'drainMs': _recorder.engine.drainDuration.inMilliseconds,
      'lifecycleInput': 'controller_session_simulation_for_R09',
      'nominalInjectionCadenceUs': ReaderScenarioRunner.nominalFrameUs,
      'injectionCadencePolicy':
          'at most one move per actual frame; no catch-up',
      'deviceModelSource': 'user_provided',
      'sectionCacheCapacity': 4,
      'resourceCaps': _reader.resourceCaps,
    };
  }

  Future<void> _start() async {
    final token = ++_captureGeneration;
    final manual = _manual || _scenario == 'R11';
    final repeats = manual ? 1 : _repeats;
    _update(() {
      _running = true;
      _error = null;
      _record = null;
    });
    try {
      if (_scenario == 'R11' && _reader.identity?.fixtureId != null) {
        throw const ParseException();
      }
      if (!manual) {
        final fixture = ReaderScenarioRunner.fixtures[_scenario];
        final books = await _inventory;
        final matches = books.where((b) => b.fixtureId == fixture);
        if (matches.isEmpty) throw const ParseException();
        _measure();
        await _reader.open(matches.first);
      }
      if (!mounted || token != _captureGeneration) return;
      _measure();
      for (var repeat = 1; repeat <= repeats; repeat++) {
        if (!mounted || token != _captureGeneration) return;
        final book = _reader.identity;
        if (book == null) throw const ParseException();
        await _recorder.start(
          runId:
              '${_recorder.engine.clock.utcNow().microsecondsSinceEpoch}-$repeat',
          bookSha256: book.sha256,
          fixtureId: book.fixtureId,
          scenarioId: _scenario,
          repeatIndex: repeat,
          repeatCount: repeats,
          input: manual ? 'manual_touch' : 'synthetic_injected',
          declarations: _declarations.copyWith(deviceModel: _model.text.trim()),
          metadata: _metadata(),
          mode: _mode,
        );
        if (!mounted || token != _captureGeneration) return;
        final runner = ReaderScenarioRunner(target: _reader, readerRect: _rect);
        _runner = runner;
        if (manual) {
          final p = _reader.turn?.accepted;
          if (p != null) {
            await _reader.jump(p.sectionIndex, page: p.pageIndex, cold: true);
          }
          _reader.snapshot();
        } else {
          // The S1 duration limit also cancels the scripted control plane.
          unawaited(
            _recorder.completed.then<void>(
              (_) {
                if (identical(_runner, runner)) runner.cancel();
              },
              onError: (Object error, StackTrace stack) {
                // Cancel the script, then let the awaited completion below
                // surface the typed failure through the normal probe UI.
                if (identical(_runner, runner)) runner.cancel();
              },
            ),
          );
          try {
            await runner.run(_scenario);
          } on ScenarioCancelled {
            await _recorder.stop(reason: 'scenario_cancelled');
          }
          if (!mounted || token != _captureGeneration) return;
          _update(() => _draining = true);
          await _recorder.stop(reason: 'scenario_complete');
        }
        final record = await _recorder.completed;
        if (!mounted || token != _captureGeneration || record == null) return;
        _update(() {
          _record = record;
          _draining = false;
        });
        final path = await _exports.export(record);
        if (!mounted || token != _captureGeneration) return;
        _update(() => _exportPath = path);
        if (record.engine.stopReason != 'scenario_complete') break;
      }
    } on AppException {
      if (mounted) _update(() => _error = context.l10n.readerFailure);
      try {
        await _recorder.stop(reason: 'probe_failure');
      } on AppException {
        // The original failure is already visible. A malformed native stop
        // report can also be the error that brought us into this handler.
      }
    } on UnsupportedLayoutException {
      if (mounted) _update(() => _error = context.l10n.readerUnsupported);
      await _recorder.stop(reason: 'unsupported_layout');
    } finally {
      _runner?.cancel();
      _runner = null;
      if (mounted && token == _captureGeneration) {
        _update(() {
          _running = false;
          _draining = false;
        });
      }
    }
  }

  void _stop() {
    _runner?.cancel();
    _reader.turn?.cancel('capture-stop');
    _reader.snapshot();
    _update(() => _draining = true);
    unawaited(_recorder.stop());
  }

  Future<void> _export() async {
    final record = _record;
    if (record == null) return;
    _update(() => _busy = true);
    try {
      final path = await _exports.export(record);
      if (!mounted) return;
      _update(() => _exportPath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.diagnosticsExported(path))),
      );
    } on AppException {
      if (mounted) _update(() => _error = context.l10n.diagnosticsStorageError);
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final record = _record;
    if (record == null) return;
    await Clipboard.setData(
      ClipboardData(text: ReaderExportRepository.clipboard(record)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.diagnosticsCopied)));
  }
}
