part of 'package:shiori/features/diagnostics/presentation/reader_probe/reader_scenario_runner.dart';

extension _ScenarioScripts on ReaderScenarioRunner {
  Future<void> _jump(int section, {int page = 0, bool cold = false}) async {
    _check();
    await target.jump(section, page: page, cold: cold);
    await waitFrames(2);
  }

  Future<void> _script(String id) async {
    switch (id) {
      case 'R01':
        await _jump(0, cold: true);
        for (final next in [true, false]) {
          for (var i = 0; i < 40; i++) {
            await target.warm();
            await tap(next);
          }
        }
      case 'R02':
        await _jump(1);
        await drag(.78, .22, 90); // ~0.3 px/ms at phone width.
        await drag(.78, .30, 6); // Flick, realistic velocity.
        await drag(.75, .25, 24, reverse: true);
        await _jump(0);
        await drag(.22, .78, 36); // First-page boundary.
        await _jump(target.sectionCount - 1, page: -1);
        await drag(.78, .22, 36); // Last-page boundary.
      case 'R03':
        await _jump(0, cold: true);
        target.holdPreparation();
        await drag(.78, .25, 30, held: true);
      case 'R04':
        await _jump(0, cold: true);
        for (var i = 0; i < 16; i++) {
          await tap(true, settle: false);
        }
        // Jump while FIFO still contains pending intents; cancellation is measured.
        await _jump(target.sectionCount - 1);
        await _waitMs(600);
      case 'R05':
        for (var i = 0; i < target.sectionCount - 1; i++) {
          await _jump(i, page: -1, cold: true);
          await tap(true); // Cold next chapter.
          await target.warm();
          await tap(false); // Warm previous chapter.
          await target.warm();
          await tap(true); // Warm next chapter.
        }
        for (var i = target.sectionCount - 1; i > 0; i--) {
          await _jump(i, cold: true);
          await tap(false); // Cold previous.
          await target.warm();
          await tap(true);
          await target.warm();
          await tap(false);
        }
      case 'R06':
        await target.longParagraph();
        await waitFrames(2);
        // Traverse the entire section, including the >=100k-code-unit block.
        final pages = target.pageCount;
        for (var i = 0; i < pages - 1; i++) {
          await tap(true);
        }
      case 'R07':
        for (var section = 0; section < target.sectionCount; section++) {
          await _jump(section);
          final pages = target.pageCount;
          for (var page = 1; page < pages; page++) {
            await tap(true);
          }
        }
      case 'R08':
        await _jump(0);
        await _jump(0, page: target.pageCount ~/ 2);
        await target.largeText();
        await waitFrames(2);
        for (var i = 0; i < 6; i++) {
          await tap(i < 3);
        }
      case 'R09':
        await _jump(0, cold: true);
        await tap(true, settle: false);
        await waitFrames(10);
        target.suspend();
        await waitFrames(20);
        await target.resume();
        await _jump(0, cold: true);
        target.holdPreparation();
        await _press(.78);
        await _move(.60);
        await waitFrames(4);
        target.suspend();
        target.releasePreparation();
        await _release();
        await waitFrames(20);
        await target.resume();
        await tap(true);
      case 'R10':
        await _jump(0, cold: true);
        target.snapshot();
        for (var i = 0; i < 100; i++) {
          await target.warm();
          await tap(i.isEven);
          target.snapshot();
        }
        for (var i = 0; i < 12; i++) {
          await _jump(
            i % target.sectionCount,
            page: i.isEven ? -1 : 0,
            cold: true,
          );
          target.snapshot();
        }
      case 'R11':
        // Manual only; the recorder reports whether >=50 turns were accepted.
        return;
    }
    target.snapshot();
  }
}
