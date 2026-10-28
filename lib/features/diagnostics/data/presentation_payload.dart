import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/presentation_probe.dart';
import 'package:shiori/features/diagnostics/data/reader_capture_budget.dart';

/// Strict native-channel boundary. Timestamps are raw native seconds.
abstract final class PresentationPayload {
  static PresentationReport parse(Object? value, PresentationMode mode) {
    final p = _map(value, 'report');
    if (p['mode'] != mode.name || p['evidence'] != mode.evidence) {
      _invalid('mode/evidence');
    }
    final available = p['available'];
    final omission = p['omission'];
    if (available is! bool ||
        (omission != null && (omission is! String || omission.isEmpty)) ||
        (!available && omission == null) ||
        (available && omission != null)) {
      _invalid('available/omission');
    }
    final inventory = _map(p['inventory'], 'inventory');
    if (inventory['layerClass'] is! String ||
        inventory['iosVersion'] is! String ||
        inventory['lowPowerMode'] is! bool ||
        !inventory.containsKey('FLTUseFlutterMetalLayer') ||
        (inventory['FLTUseFlutterMetalLayer'] != null &&
            inventory['FLTUseFlutterMetalLayer'] is! bool)) {
      _invalid('inventory');
    }
    _integer(inventory['maximumFramesPerSecond'], 'maximumFramesPerSecond');
    _integer(inventory['thermalState'], 'thermalState');
    final budgetVersion = inventory['captureBudgetVersion'];
    if (budgetVersion != null &&
        (budgetVersion is! int || budgetVersion != 1)) {
      _invalid('captureBudgetVersion');
    }
    final capacity = budgetVersion == 1
        ? ReaderCaptureBudget.nativeCapacity
        : 16384;
    if (_integer(inventory['ringCapacity'], 'ringCapacity') != capacity) {
      _invalid('ringCapacity');
    }
    if (available) {
      switch (mode) {
        case PresentationMode.a1 || PresentationMode.a2:
          if (inventory['layerClass'] != 'FlutterMetalLayer') {
            _invalid('layerClass for A');
          }
        case PresentationMode.b:
          if (inventory['layerClass'] != 'CAMetalLayer' ||
              inventory['FLTUseFlutterMetalLayer'] != false) {
            _invalid('layerClass/plist for B');
          }
        case PresentationMode.inventory:
          break;
      }
    }
    final raw = p['samples'];
    if (raw is! List<Object?> || raw.length > capacity) _invalid('samples');
    final samples = <Map<String, Object?>>[];
    for (final entry in raw) {
      final s = _map(entry, 'sample');
      _seconds(s['timestamp'], 'timestamp');
      switch (s['kind']) {
        case 'layer_commit':
          if (mode != PresentationMode.a1 && mode != PresentationMode.a2) {
            _invalid('layer_commit mode');
          }
          if (s.length != 2) _invalid('layer_commit fields');
        case 'display_link':
          if (mode != PresentationMode.a2) _invalid('display_link mode');
          _seconds(s['targetTimestamp'], 'targetTimestamp');
          if ((s['targetTimestamp'] as num) < (s['timestamp'] as num) ||
              s.length != 3) {
            _invalid('display_link period');
          }
        case 'drawable':
          if (mode != PresentationMode.b) _invalid('drawable mode');
          _seconds(s['presentedTime'], 'presentedTime');
          final id = s['drawableId'];
          if (id is! String ||
              !RegExp(r'^[0-9]{1,20}$').hasMatch(id) ||
              BigInt.parse(id) > BigInt.parse('18446744073709551615') ||
              s.length != 4) {
            _invalid('drawableId/fields');
          }
        default:
          _invalid('sample kind');
      }
      samples.add(Map.unmodifiable(s));
    }
    if (available && mode != PresentationMode.inventory && samples.isEmpty) {
      _invalid('available without samples');
    }
    if (available &&
        mode == PresentationMode.a2 &&
        (!samples.any((s) => s['kind'] == 'layer_commit') ||
            !samples.any((s) => s['kind'] == 'display_link'))) {
      _invalid('A2 streams');
    }
    final overflow = _integer(p['overflow'], 'overflow');
    final contention = _integer(p['contentionDrops'], 'contentionDrops');
    final unmatched = _integer(
      p['unmatchedCallbacks'] ?? 0,
      'unmatchedCallbacks',
    );
    if (contention > overflow) _invalid('contentionDrops');
    final lossVersion = p['lossAccountingVersion'];
    if (lossVersion != null && (lossVersion is! int || lossVersion != 1)) {
      _invalid('lossAccountingVersion');
    }
    return PresentationReport(
      available: available,
      evidence: mode.evidence,
      omission: omission as String?,
      // Only whitelisted metadata crosses into a book-safe export.
      inventory: Map.unmodifiable({
        for (final key in [
          'layerClass',
          'FLTUseFlutterMetalLayer',
          'maximumFramesPerSecond',
          'lowPowerMode',
          'thermalState',
          'iosVersion',
          'ringCapacity',
        ])
          key: inventory[key],
        'captureBudgetVersion': ?budgetVersion,
      }),
      samples: List.unmodifiable(samples),
      overflow: overflow,
      contentionDrops: contention,
      unmatchedCallbacks: unmatched,
      lossAccountingVersion: lossVersion as int?,
    );
  }

  static Map<String, Object?> _map(Object? value, String field) {
    if (value is! Map<Object?, Object?> ||
        value.keys.any((key) => key is! String)) {
      _invalid(field);
    }
    return value.cast<String, Object?>();
  }

  static int _integer(Object? value, String field) {
    if (value is! int || value < 0) _invalid(field);
    return value;
  }

  static void _seconds(Object? value, String field) {
    if (value is! num || !value.isFinite || value < 0) _invalid(field);
  }

  static Never _invalid(String field) => throw ParseException(
    FormatException('Invalid presentation payload: $field'),
  );
}
