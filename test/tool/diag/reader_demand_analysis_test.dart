import 'package:flutter_test/flutter_test.dart';

import '../../../tool/diag/reader_demand_analysis.dart';
import '../../../tool/diag/reader_export_data.dart';

Json e(String event, int time, {int id = 1, int epoch = 1}) => {
  'event': event,
  'monotonicUs': time,
  'inputId': id,
  'captureEpoch': epoch,
};
ReaderDemandAnalysis replay(List<Json> events, {int stop = 200000}) =>
    ReaderDemandAnalysis(events, {
      'readerDemandVersion': 1,
      'captureEpoch': 1,
    }, stop);
void main() {
  test('recognition excludes dwell; queue excludes warm latency', () {
    final a = replay([
      e('inputReceived', 0),
      e('pointerAdmitted', 1),
      e('inputRecognized', 100000),
      e('recognizedAdmission', 100000),
      e('visualMutation', 100001),
      e('motionSubmission', 108000),
      e('inputRecognized', 110000, id: 2),
      e('queued', 110001, id: 2),
      e('recognizedAdmission', 130000, id: 2),
      e('motionSubmission', 138000, id: 2),
    ]);
    expect(a.latencies, [8000]);
    expect(a.invalidTransitions, 0);
  });
  test('demand without ANY first submission measured through capture stop', () {
    final a = replay([
      e('inputRecognized', 0),
      e('recognizedAdmission', 0),
      e('frameDemandStart', 1000),
    ], stop: 51000);
    expect(a.candidates.single['us'], 50000);
    expect(a.incompleteInputs, 1);
    expect(a.openIntervals, 1);
  });
  test('hold cannot exempt dirty mutation or frame demand', () {
    final a = replay([
      e('holdStart', 0),
      e('dragDirty', 1000),
      e('visualMutation', 2000),
      e('frameDemandStart', 3000),
    ], stop: 100000);
    expect(a.holds, [100000]);
    expect(a.candidates, hasLength(3));
    expect(a.candidates.every((c) => c['class'] == 'dueLateOrMissing'), true);
  });
  test('clean held pointer has no fake overdue frame', () {
    final a = replay([
      e('inputRecognized', 0),
      e('recognizedAdmission', 0),
      e('frameDemandStart', 1),
      e('dragDirty', 1),
      e('dragClean', 5000),
      e('visualMutation', 5000),
      e('frameDemandEnd', 5000),
      e('holdStart', 5000),
      e('motionSubmission', 8000),
      e('holdEnd', 190000),
    ]);
    expect(a.holds, [185000]);
    expect(a.candidates, isEmpty);
    expect(a.openIntervals, 0);
  });
  test('final mutation and late submission remain measured', () {
    final a = replay([
      e('visualMutation', 1),
      e('motionSubmission', 8000),
      e('visualMutation', 9000),
      e('motionSubmission', 59000),
    ]);
    expect(a.candidates.single['source'], 'mutationToSubmission');
    expect(a.candidates.single['us'], 50000);
  });
  test('foreign epochs cannot close barriers or fabricate capability', () {
    final a = replay([
      e('preparationBarrierStart', 0),
      e('preparationBarrierEnd', 1, epoch: 2),
    ]);
    expect(a.openBarriers, 1);
    expect(ReaderDemandAnalysis([], {}, 0).available, false);
    expect(
      () => replay([e('holdStart', 3), e('holdEnd', 2)]),
      throwsFormatException,
    );
  });
  test(
    'dirty-to-clean deadline is measured even with a completed interval',
    () {
      final a = replay([
        e('dragDirty', 1000),
        e('holdStart', 2000),
        e('dragClean', 51000),
      ]);
      expect(a.candidates.single['source'], 'dirtyDrag');
      expect(a.candidates.single['us'], 50000);
    },
  );
  test('a capability marker cannot fabricate a complete demand chain', () {
    final a = replay([
      e('inputRecognized', 0),
      e('recognizedAdmission', 1),
      e('motionSubmission', 8000),
    ]);
    expect(a.incompleteDemandInputs, 1);
    expect(a.demandStarts, 0);
    expect(a.mutations, 0);
  });
  test('a painted reset satisfies superseded visible mutations', () {
    final a = ReaderDemandAnalysis(
      [
        e('visualMutation', 1000),
        {...e('visualMutation', 3000), 'inputId': null},
        {...e('motionSubmission', 8000), 'inputId': null},
      ],
      {'readerDemandVersion': 1, 'captureEpoch': 1},
      100000,
    );
    expect(a.openIntervals, 0);
    expect(a.candidates, isEmpty);
    expect(a.mutations, 2);
    expect(a.submissions, 1);
  });
}
