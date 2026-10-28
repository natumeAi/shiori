import 'reader_demand_analysis.dart';
import 'reader_capture_analysis.dart';
import 'reader_engine_analysis.dart';
import 'reader_correctness_analysis.dart';
import 'reader_resource_gate.dart';
import 'reader_export_data.dart';
import 'reader_input_analysis.dart';
import 'reader_native_resources.dart';

final class ReaderExportAnalysis {
  ReaderExportAnalysis(this.raw, {this.source = '<memory>'}) {
    if (raw['kind'] != 'reader_feasibility') {
      throw FormatException('Unsupported kind: ${raw['kind']}');
    }
    if (raw['schemaVersion'] is! int || raw['schemaVersion'] != 1) {
      throw FormatException(
        'Unsupported schemaVersion: ${raw['schemaVersion']} (expected integer 1)',
      );
    }
    scenario = string(raw['scenarioId'], 'scenarioId');
    repeat = integer(raw['repeatIndex'], 'repeatIndex');
    repeatCount = integer(raw['repeatCount'], 'repeatCount');
    if (repeat < 1 || repeatCount < repeat) {
      throw const FormatException('Invalid repeat index/count');
    }
    final engineRaw = object(raw['engine'], 'engine');
    engine = EngineAnalysis(engineRaw);
    inputs = InputAnalysis(
      objects(raw['readerEvents'], 'readerEvents'),
      objects(raw['layoutCosts'], 'layoutCosts'),
      objects(raw['resources'], 'resources'),
    );
    metadata = object(engineRaw['metadata'], 'engine.metadata');
    correctness = correctnessAnalysis(
      objects(raw['readerEvents'], 'events'),
      metadata,
    );
    resources = resourceTrends(objects(raw['resources'], 'resources'));
    native = nativeAnalysis(object(raw['presentation'], 'presentation'));
    demand = ReaderDemandAnalysis(
      objects(raw['readerEvents'], 'readerEvents'),
      metadata,
      integer(engineRaw['stoppedMonotonicUs'], 'stoppedMonotonicUs'),
    );
    stalls = engine.stalls(inputs.windows);
    if (demand.available) {
      final longStages = objects(
        stalls['candidates'],
        'candidates',
      ).where((c) => c['source'] == 'longStage').toList();
      stalls['candidates'] = [...longStages, ...demand.candidates];
      stalls['observed'] =
          longStages.isNotEmpty || demand.candidates.isNotEmpty;
      stalls['classes'] = {
        'recordedDeliberateHold': demand.holds.length,
        'provenIdleNoFrameRequested': 0,
        'dueLateOrMissing': longStages.length + demand.candidates.length,
        'unresolved': 0,
      };
      stalls['demandTimeline'] = demand.report;
    }
    overflow = object(raw['overflow'], 'overflow');
    omissions = object(raw['omissions'], 'omissions');
    captureBudget = captureBudgetGate(raw);
    mismatches = [
      ...differences(
        object(raw['aggregates'], 'aggregates'),
        inputs.appAggregates,
      ),
      ...differences(
        object(engineRaw['aggregates'], 'engine.aggregates'),
        engine.aggregates,
        'engine.aggregates',
      ),
    ];
  }

  final Json raw;
  final String source;
  late final String scenario;
  late final int repeat, repeatCount;
  late final EngineAnalysis engine;
  late final InputAnalysis inputs;
  late final ReaderDemandAnalysis demand;
  late final Json resources,
      native,
      stalls,
      overflow,
      omissions,
      metadata,
      correctness;
  late final List<String> mismatches;
  late final GateRow captureBudget;
  Json get readerAggregates => inputs.appAggregates;
  bool lost(String key) => number(overflow[key], 'overflow.$key') > 0;

  List<GateRow> get gates {
    final rows = <GateRow>[captureBudget];
    void gate(
      String name,
      Object? value,
      String threshold,
      bool? pass,
      String reason,
    ) {
      rows.add(
        GateRow(
          name,
          '$value',
          threshold,
          pass == null
              ? 'unavailable'
              : pass
              ? 'pass'
              : 'fail',
          reason,
        ),
      );
    }

    for (final stage in ['ui', 'raster']) {
      final d = object(engine.aggregates[stage], stage);
      final count = d['count'] as int;
      final fraction = count == 0
          ? null
          : (count - (d['over8333Us'] as int)) / count;
      final failed =
          fraction != null && fraction < ReaderGates.minimumWithinBudget;
      gate(
        '$stage motion budget',
        fraction == null ? null : '${(fraction * 100).toStringAsFixed(2)}%',
        '>=99% <=${ReaderGates.stageBudgetUs} us',
        failed
            ? false
            : count == 0 || lost('frames') || lost('motion')
            ? null
            : true,
        count == 0
            ? 'no matched nonnegative frame IDs'
            : lost('frames') || lost('motion')
            ? 'overflow: retained samples only'
            : 'retained engine-matched motion samples; trailing batch may be incomplete',
      );
    }
    final p95 = demand.latency['p95Us'] as int?;
    gate(
      'warm admitted input to first submission',
      p95,
      'P95 <=${ReaderGates.warmSubmissionP95Us} us',
      p95 != null && p95 > ReaderGates.warmSubmissionP95Us
          ? false
          : !demand.available ||
                p95 == null ||
                demand.invalidTransitions > 0 ||
                demand.incompleteInputs > 0 ||
                lost('events')
          ? null
          : true,
      demand.available
          ? 'actual recognized admission; queued/cold inputs excluded; incomplete=${demand.incompleteInputs}'
          : 'legacy export: recognized admission is not recorded; capability unavailable',
    );
    final modernComplete =
        demand.available &&
        demand.recognizedInputs > 0 &&
        demand.openIntervals == 0 &&
        demand.openBarriers == 0 &&
        demand.invalidTransitions == 0 &&
        demand.incompleteInputs == 0 &&
        demand.incompleteDemandInputs == 0 &&
        demand.demandStarts > 0 &&
        demand.mutations > 0 &&
        demand.submissions > 0;
    final legacyIncomplete =
        inputs.windows.isEmpty ||
        inputs.openWindows > 0 ||
        engine.intervals.isEmpty ||
        engine.unavailableFrameNumbers > 0 ||
        engine.unmatchedMotionIds > 0 ||
        (stalls['brokenAdjacencyInsideWindows'] as int) > 0;
    gate(
      'motion stalls',
      stalls['observed'],
      'no unexplained >=${ReaderGates.stallUs} us stall',
      stalls['observed'] == true
          ? false
          : lost('events') ||
                lost('frames') ||
                lost('motion') ||
                (demand.available ? !modernComplete : legacyIncomplete)
          ? null
          : true,
      demand.available
          ? 'actual demand including pending intervals through capture stop; holds do not excuse dirty/mutation demand'
          : 'legacy bounded windows; missing demand cannot explain observed gaps',
    );
    final proofs = readerAggregates['proofFailures'] as int;
    gate(
      'proof failures',
      proofs,
      '${ReaderGates.correctnessFailures}',
      proofs > 0
          ? false
          : lost('events') || inputs.destinations.isEmpty
          ? null
          : true,
      'observed proof outcomes only; event overflow=${overflow['events']}',
    );
    final failures = correctness['failures'] as int? ?? 0;
    gate(
      'correctness / committed destinations / stale callbacks',
      correctness['available'] == true
          ? correctness['committedInputs']
          : 'unverified',
      'zero proof/stale publication failures; exactly one acceptance per commit; no uncommitted acceptance',
      failures > ReaderGates.correctnessFailures
          ? false
          : correctness['available'] != true || lost('events')
          ? null
          : true,
      '${correctness['reason']}; failures=$failures; event overflow=${overflow['events']}',
    );
    rows.add(
      resourceGate(
        resources,
        objects(raw['resources'], 'resources'),
        metadata,
        readerAggregates['acceptedTurns'] as int,
        overflow: lost('events') || lost('resources'),
      ),
    );
    final available = native['available'] == true;
    gate(
      'native evidence (${native['mode']})',
      native['evidence'],
      'report at recorded evidence level',
      available ? true : null,
      available
          ? 'native-clock evidence only; overflow=${native['overflow']}; contentionDrops=${native['contentionDrops']} (subset); unmatchedCallbacks=${native['unmatchedCallbacks']} (separate)'
          : '${native['omission']}',
    );
    gate(
      'native sample loss',
      native['overflow'],
      'zero native losses and unmatched callbacks',
      (native['overflow'] as num) > 0 ||
              (native['unmatchedCallbacks'] as num) > 0
          ? false
          : available && native['lossAccountingVersion'] == 1
          ? true
          : null,
      'contention is included in overflow; unmatched callbacks are separate; legacy capture lacks complete loss accounting',
    );
    gate(
      'physical presentation / touch-to-photon',
      'unverified',
      'independent presentation evidence',
      null,
      'engine identity, layer commits and non-product B samples do not establish physical presentation or touch-to-photon latency',
    );
    return rows;
  }
}
