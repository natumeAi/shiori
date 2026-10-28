import 'reader_export_data.dart';

/// Replays actual controller demand in the recorder's monotonic domain. No
/// engine/native timestamp offsets, script intentions, or legacy admission.
final class ReaderDemandAnalysis {
  ReaderDemandAnalysis(List<Json> events, Json metadata, int stoppedUs) {
    available = metadata['readerDemandVersion'] == 1;
    if (!available) return;
    final epoch = integer(metadata['captureEpoch'], 'captureEpoch');
    final states = <int, _DemandInput>{};
    var previous = -1;
    void overdue(int start, int end, int id, String source) {
      if (end - start >= ReaderGates.stallUs) {
        candidates.add({
          'source': source,
          'captureEpoch': epoch,
          'inputId': id,
          'startUs': start,
          'endUs': end,
          'us': end - start,
          'class': 'dueLateOrMissing',
        });
      }
    }

    for (final event in events) {
      final time = integer(event['monotonicUs'], 'event.monotonicUs');
      if (time < previous || time > stoppedUs) {
        throw const FormatException('Demand timeline is not monotonic');
      }
      previous = time;
      final rawId = event['inputId'];
      final globalMutation =
          rawId == null &&
          (event['event'] == 'visualMutation' ||
              event['event'] == 'motionSubmission');
      if ((rawId is! int && !globalMutation) ||
          event['captureEpoch'] != epoch) {
        continue;
      }
      final id = rawId is int ? rawId : 0;
      final state = states.putIfAbsent(id, _DemandInput.new);
      switch (event['event']) {
        case 'inputRecognized':
          state.recognized ??= time;
        case 'recognizedAdmission':
          state.admitted ??= time;
          if (state.recognized == null || state.recognized! > time) {
            invalidTransitions++;
          }
        case 'queued':
          state.queued = true;
        case 'preparationMiss':
          state.warm = false;
        case 'staticFallback' || 'reducedMotion' || 'noMotionRequired':
          state.noMotion = true;
        case 'frameDemandStart':
          demandStarts++;
          state.hadDemand = true;
          if (state.demand != null) invalidTransitions++;
          state.demand ??= time;
        case 'frameDemandEnd':
          if (state.demand case final start?) {
            overdue(start, time, id, 'frameDemand');
          } else {
            invalidTransitions++;
          }
          state.demand = null;
        case 'visualMutation':
          mutations++;
          state.hadMutation = true;
          state.mutation ??= time;
        case 'motionSubmission':
          submissions++;
          // The surface coalesces all writes before the same paint. Its final
          // submission satisfies the visible global state, including a reset
          // that superseded an older input's last unpainted offset.
          for (final pending in states.entries) {
            if (pending.value.mutation case final start?) {
              overdue(start, time, pending.key, 'mutationToSubmission');
              pending.value.mutation = null;
            }
          }
          if (state.demand case final start?) {
            overdue(start, time, id, 'frameDemand');
            state.demand = time;
          }
          state.mutation = null;
          state.first ??= time;
        case 'dragDirty':
          state.dirty ??= time;
        case 'dragClean':
          if (state.dirty case final start?) {
            overdue(start, time, id, 'dirtyDrag');
          }
          state.dirty = null;
        case 'holdStart':
          state.hold = time;
        case 'holdEnd':
          if (state.hold case final start?) {
            holds.add(time - start);
          }
          state.hold = null;
        case 'preparationBarrierStart':
          state.barriers++;
        case 'preparationBarrierEnd':
          if (state.barriers == 0) {
            invalidTransitions++;
          } else {
            state.barriers--;
          }
        case 'cancelled' || 'failed':
          state.noMotion = true;
      }
    }
    for (final entry in states.entries) {
      final s = entry.value;
      for (final pending in [
        (s.demand, 'pendingFrameDemand'),
        (s.mutation, 'pendingVisualMutation'),
        (s.dirty, 'pendingDirtyDrag'),
      ]) {
        if (pending.$1 case final start?) {
          overdue(start, stoppedUs, entry.key, pending.$2);
          openIntervals++;
        }
      }
      if (s.hold case final start?) holds.add(stoppedUs - start);
      openBarriers += s.barriers;
      if (s.admitted != null && !s.noMotion) {
        recognizedInputs++;
        if (!s.hadDemand || !s.hadMutation) incompleteDemandInputs++;
        if (s.first == null) {
          incompleteInputs++;
        } else if (s.first! < s.admitted!) {
          invalidTransitions++;
        } else if (s.warm && !s.queued) {
          latencies.add(s.first! - s.admitted!);
        }
      }
    }
  }

  bool available = false;
  int invalidTransitions = 0, incompleteInputs = 0, recognizedInputs = 0;
  int openIntervals = 0, openBarriers = 0, incompleteDemandInputs = 0;
  int demandStarts = 0, mutations = 0, submissions = 0;
  final candidates = <Json>[];
  final holds = <int>[];
  final latencies = <int>[];
  Json get latency => distribution(latencies);
  Json get report => {
    'available': available,
    'recognizedInputs': recognizedInputs,
    'demandStarts': demandStarts,
    'visualMutations': mutations,
    'motionSubmissions': submissions,
    'incompleteDemandInputs': incompleteDemandInputs,
    'invalidTransitions': invalidTransitions,
    'incompleteInputs': incompleteInputs,
    'openIntervals': openIntervals,
    'openPreparationBarriers': openBarriers,
    'recognizedAdmissionToFirstSubmission': latency,
    'recordedHolds': distribution(holds),
    'overdue': candidates,
    'interpretation': 'holds never cancel dirty, mutation or frame demand; open demand measured through capture stop; native and engine clocks remain separate',
  };
}

final class _DemandInput {
  int? recognized, admitted, first, demand, mutation, dirty, hold;
  int barriers = 0;
  bool queued = false, warm = true, noMotion = false;
  bool hadDemand = false, hadMutation = false;
}
