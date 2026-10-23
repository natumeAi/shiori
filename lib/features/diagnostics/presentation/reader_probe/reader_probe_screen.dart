import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/config/env.dart';
import 'package:shiori/core/diagnostics/diagnostic_recorder.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
import 'package:shiori/core/diagnostics/scheduler_frame_source.dart';
import 'package:shiori/core/diagnostics/system_probe_clock.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/features/diagnostics/data/method_channel_presentation_probe.dart';
import 'package:shiori/features/diagnostics/data/presentation_probe.dart';
import 'package:shiori/features/diagnostics/data/probe_book_repository.dart';
import 'package:shiori/features/diagnostics/data/reader_export_repository.dart';
import 'package:shiori/features/diagnostics/data/reader_feasibility_record.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_recorder.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_controller.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_controls.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_scenario_runner.dart';
import 'package:shiori/features/reader/engine/support/unsupported_layout.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/motion/turn_clock.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader.dart';
import 'package:shiori/l10n/l10n.dart';

part 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_capture.dart';

class ReaderProbeScreen extends ConsumerStatefulWidget {
  const ReaderProbeScreen({
    super.key,
    this.books,
    this.exports,
    this.recorder,
    this.openBook,
    this.clockFactory,
  });
  final ProbeBookRepository? books;
  final ReaderExportRepository? exports;
  final ReaderProbeRecorder? recorder;
  final Future<EpubBook> Function(Uint8List)? openBook;
  final TurnClock Function()? clockFactory;
  @override
  ConsumerState<ReaderProbeScreen> createState() => _ReaderProbeScreenState();
}

class _ReaderProbeScreenState extends ConsumerState<ReaderProbeScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _viewport = GlobalKey();
  final _model = TextEditingController();
  late final ProbeBookRepository _books;
  late final ReaderExportRepository _exports;
  late final ReaderProbeRecorder _recorder;
  late final ReaderProbeController _reader;
  late Future<List<ProbeBook>> _inventory;
  ReaderScenarioRunner? _runner;
  ReaderFeasibilityRecord? _record;
  ProbeDeclarations _declarations = const ProbeDeclarations();
  String _scenario = 'R01';
  int _repeats = 3;
  bool _manual = false, _busy = false, _running = false, _draining = false;
  bool _choosing = true;
  String? _error, _exportPath;
  PresentationMode _mode = PresentationMode.a1;
  int _captureGeneration = 0;
  @override
  void initState() {
    super.initState();
    final directories = ref.read(appDirectoriesProvider);
    _books = widget.books ?? ProbeBookRepository(directories);
    _exports = widget.exports ?? ReaderExportRepository(directories);
    _recorder =
        widget.recorder ??
        ReaderProbeRecorder(
          presentation: MethodChannelPresentationProbe(),
          engine: DiagnosticRecorder(
            clock: SystemProbeClock(),
            source: SchedulerFrameSource(),
            capacity: 65536,
            maximumDuration: const Duration(minutes: 10),
          ),
        );
    _reader = ReaderProbeController(
      _recorder,
      openBook: widget.openBook,
      clockFactory: widget.clockFactory,
    )..addListener(_changed);
    _inventory = _books.list();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _update(VoidCallback change) {
    if (mounted) setState(change);
  }

  Rect _rect() {
    final box = _viewport.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) throw const ScenarioCancelled();
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _measure() {
    final rect = _rect();
    _reader.width = rect.width;
    _reader.height = rect.height;
    _reader.dpr = View.of(context).devicePixelRatio;
  }

  Future<void> _open(ProbeBook book) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _measure();
      await _reader.open(book);
      if (!mounted) return;
      setState(() => _choosing = false);
    } on UnsupportedLayoutException {
      if (mounted) setState(() => _error = context.l10n.readerUnsupported);
    } on AppException {
      if (mounted) setState(() => _error = context.l10n.readerFailure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AppException {
      if (mounted) setState(() => _error = context.l10n.readerFailure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = _reader.session;
    final turn = _reader.turn;
    final controls = ReaderProbeControls(
      controller: _reader,
      busy: _busy || _running,
      scenario: _scenario,
      repeats: _repeats,
      manual: _manual,
      declarations: _declarations,
      model: _model,
      mode: _mode,
      onScenario: (v) => setState(() => _scenario = v),
      onRepeats: (v) => setState(() => _repeats = v),
      onManual: (v) => setState(() => _manual = v),
      onDeclarations: (v) => setState(() => _declarations = v),
      onMode: (v) => setState(() => _mode = v),
      onSettings: (v) => _action(() => _reader.reflow(v)),
      onReducedMotion: (v) => setState(() {
        _reader.reducedMotion = v;
        _reader.turn?.configure(reducedMotion: v);
      }),
      onJump: (v) => _action(() => _reader.jump(v)),
      onBooks: () {
        _scaffold.currentState?.closeEndDrawer();
        setState(() {
          _choosing = true;
          _inventory = _books.list();
        });
      },
    );
    return Scaffold(
      key: _scaffold,
      appBar: AppBar(
        title: Text(l.readerProbeTitle),
        actions: [
          IconButton(
            tooltip: l.readerProbeControls,
            icon: const Icon(Icons.tune),
            onPressed: () => _scaffold.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              spacing: 12,
              children: [
                if (_running) Text(l.readerRunning),
                if (_exportPath != null)
                  Text(l.diagnosticsExported(_exportPath!)),
                controls,
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          ValueListenableBuilder(
            valueListenable: _reader.accepted,
            builder: (_, p, _) => p == null
                ? Text(l.readerProbeTitle)
                : Text(
                    l.readerPosition(
                      p.sectionIndex + 1,
                      p.pageIndex + 1,
                      p.pageCount,
                    ),
                  ),
          ),
          Expanded(
            child: SizedBox.expand(
              key: _viewport,
              child: Stack(
                children: [
                  if (session != null && turn != null)
                    Positioned.fill(
                      child: Semantics(
                        label: l.readerProbeTitle,
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            disableAnimations:
                                _reader.reducedMotion ||
                                MediaQuery.disableAnimationsOf(context),
                          ),
                          child: PreparedReader(
                            key: ValueKey(turn),
                            controller: turn,
                            session: session,
                            closeOnDispose: false,
                          ),
                        ),
                      ),
                    ),
                  if (_choosing || session == null)
                    Positioned.fill(
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        child: _BookList(
                          inventory: _inventory,
                          enabled: !_busy && !_running,
                          onOpen: _open,
                          onRetry: () => setState(() {
                            _inventory = _books.list();
                          }),
                        ),
                      ),
                    ),
                  if (_busy || _draining)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Material(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_error!),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy || _running || _choosing ? null : _start,
                  child: Text(l.readerStart),
                ),
                OutlinedButton(
                  onPressed: _running && !_draining ? _stop : null,
                  child: Text(l.diagnosticsStop),
                ),
                OutlinedButton(
                  onPressed: _record != null && !_running && !_busy
                      ? _export
                      : null,
                  child: Text(l.diagnosticsExport),
                ),
                OutlinedButton(
                  onPressed: _record != null && !_running ? _copy : null,
                  child: Text(l.diagnosticsCopy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ++_captureGeneration;
    _runner?.cancel();
    _reader.removeListener(_changed);
    _reader.dispose();
    _recorder.dispose();
    _model.dispose();
    super.dispose();
  }
}

class _BookList extends StatelessWidget {
  const _BookList({
    required this.inventory,
    required this.enabled,
    required this.onOpen,
    required this.onRetry,
  });
  final Future<List<ProbeBook>> inventory;
  final bool enabled;
  final ValueChanged<ProbeBook> onOpen;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: inventory,
    builder: (context, snapshot) {
      final l = context.l10n;
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.diagnosticsStorageError),
              OutlinedButton(
                onPressed: enabled ? onRetry : null,
                child: Text(l.readerBooks),
              ),
            ],
          ),
        );
      }
      final books = snapshot.data ?? [];
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.readerProbeHelp),
          ),
          if (books.isEmpty) Text(l.readerEmpty),
          for (final book in books)
            ListTile(
              title: Text(
                book.fixtureId == null
                    ? l.readerUserBook(book.sha256)
                    : l.readerFixture(book.fixtureId!),
              ),
              onTap: enabled ? () => onOpen(book) : null,
            ),
        ],
      );
    },
  );
}
