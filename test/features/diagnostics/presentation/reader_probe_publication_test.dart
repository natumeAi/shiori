import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_controller.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';

import '../../../helpers/reader_probe_fixtures.dart';
import '../../reader/engine/surface/publication_fixed_test_support.dart';
import '../../library/data/publications/prepare_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'probe opens a fixed mixed publication through the real session',
    () async {
      final h = await PrepareHarness.create();
      h.bytes = corpusPublication('mixed-navigation-positive');
      final ready = await h.service.prepare(h.key);
      final recorder = readerRecorder();
      addTearDown(recorder.dispose);
      final controller = ReaderProbeController(recorder)
        ..width = 600
        ..height = 400
        ..dpr = 1;
      addTearDown(controller.dispose);
      final opened = await controller.openPublication(
        book: ready,
        activation: h.session,
        isCurrent: h.f.guard.isCurrent,
        acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
        queue: h.service.queue,
        worker: h.service.worker.get,
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        section: 1,
      );
      expect(opened, true);
      expect(controller.session, isNotNull);
      expect(controller.sectionCount, 6);
      expect(controller.session!.position.sectionIndex, 1);
      expect(controller.session!.unit!.kind.name, 'fixedSingle');
      controller.dispose();
      await controller.session!.closed;
      ready.release();
    },
  );

  test('probe leaves a reflow-only publication on the reflow path', () async {
    final h = await PrepareHarness.create();
    final ready = await h.service.prepare(h.key);
    final recorder = readerRecorder();
    addTearDown(recorder.dispose);
    final controller = ReaderProbeController(recorder);
    addTearDown(controller.dispose);
    final opened = await controller.openPublication(
      book: ready,
      activation: h.session,
      isCurrent: h.f.guard.isCurrent,
      acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
      queue: h.service.queue,
      worker: h.service.worker.get,
      fonts: FontRegistry(processBudget: ProcessFontBudget()),
    );
    expect(opened, false);
    expect(controller.session, isNull);
    ready.release();
  });
}
