import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/diagnostics/data/reader_capture_budget.dart';
import 'package:shiori/features/diagnostics/data/reader_event_buffer.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';

void main() {
  test(
    'packed rows preserve every event field through inspection and reset',
    () {
      final buffer = ReaderEventBuffer(2);
      addTearDown(buffer.dispose);
      buffer.add(
        kind: TurnTimingEvent.accepted.index,
        sequence: 1,
        monotonicUs: 9007199254740991,
        value: -0.25,
        generation: -9,
        activeGeneration: 10,
        epoch: 3,
        inputId: 11,
        queueOrFrame: 12,
        section: 13,
        page: 14,
        layoutGeneration: 15,
        pageIdentity: 'digest',
      );
      final inspection = buffer.snapshot();
      buffer.add(
        kind: ReaderEventBuffer.submission,
        sequence: 2,
        monotonicUs: 9007199254740991,
        generation: -9,
        queueOrFrame: 16,
        value: -0.0,
      );
      expect(inspection.single, {
        'event': 'accepted',
        'sequence': 1,
        'monotonicUs': 9007199254740991,
        'turnClockMs': -0.25,
        'generation': -9,
        'activeGeneration': 10,
        'captureEpoch': 3,
        'inputId': 11,
        'queueDepth': 12,
        'destination': {
          'sectionIndex': 13,
          'pageIndex': 14,
          'layoutGeneration': 15,
          'pageIdentity': 'digest',
        },
      });
      final sealed = buffer.snapshot(seal: true);
      expect(sealed.last, {
        'event': 'motionSubmission',
        'sequence': 2,
        'monotonicUs': 9007199254740991,
        'generation': -9,
        'captureEpoch': null,
        'inputId': null,
        'frameNumber': 16,
        'offset': -0.0,
      });
      expect((sealed.last['offset'] as double).isNegative, true);
      expect(() => sealed.clear(), throwsUnsupportedError);
      buffer.clear();
      buffer.add(
        kind: ReaderEventBuffer.preparationStart,
        sequence: 1,
        monotonicUs: 2,
        section: 9,
        cacheHit: true,
      );
      expect(buffer.snapshot().single, {
        'sequence': 1,
        'event': 'sectionPreparationStart',
        'monotonicUs': 2,
        'section': 9,
        'cacheHit': true,
      });
      expect(sealed.first['captureEpoch'], 3);
      expect(sealed.last['sequence'], 2);
    },
  );

  test(
    'actual worst-case envelope appends without growth, reduction or loss',
    () {
      final buffer = ReaderEventBuffer(ReaderCaptureBudget.eventCapacity);
      addTearDown(buffer.dispose);
      final bytes = buffer.numericBytes;
      for (var i = 1; i <= ReaderCaptureBudget.requiredEvents; i++) {
        buffer.add(
          kind: TurnTimingEvent.dragDirty.index,
          sequence: i,
          monotonicUs: i,
          generation: 1,
          activeGeneration: 1,
          epoch: 1,
          inputId: 1,
        );
      }
      expect(buffer.numericBytes, bytes);
      expect(buffer.materializedRows, 0);
      expect(buffer.overflow, 0);
      final snapshot = buffer.snapshot(seal: true);
      expect(snapshot.length, 675456);
      expect(snapshot.first['sequence'], 1);
      expect(snapshot.last['sequence'], 675456);
    },
  );
}
