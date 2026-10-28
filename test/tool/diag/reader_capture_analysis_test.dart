import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/reader_capture_budget.dart';
import 'package:shiori/features/diagnostics/data/reader_export_repository.dart';

import '../../../tool/diag/reader_capture_analysis.dart';
import '../../../tool/diag/reader_export_data.dart';

Json capture() {
  final raw = jsonDecode(
    File('test/fixtures/reader/exports/passing-120hz-a1-1.json')
        .readAsStringSync(),
  ) as Json;
  final metadata = object(
    object(raw['engine'], 'engine')['metadata'],
    'metadata',
  );
  metadata['readerCaptureBudget'] = ReaderCaptureBudget.describe(
    events: ReaderCaptureBudget.eventCapacity,
    auxiliary: ReaderCaptureBudget.auxiliaryCapacity,
    engine: ReaderCaptureBudget.engineCapacity,
    maximumMs: 600000,
  );
  final presentation = object(raw['presentation'], 'presentation');
  presentation['lossAccountingVersion'] = 1;
  object(presentation['inventory'], 'inventory')
    ..['ringCapacity'] = ReaderCaptureBudget.nativeCapacity
    ..['captureBudgetVersion'] = 1;
  // The archived legacy fixture has complete sequence identities already.
  return raw;
}

void main() {
  test('legacy remains readable but cannot claim versioned long capacity', () {
    final raw = capture();
    object(
      object(raw['engine'], 'engine')['metadata'],
      'metadata',
    ).remove('readerCaptureBudget');
    expect(ReaderExportRepository.decode(jsonEncode(raw)).schemaVersion, 1);
    expect(captureBudgetGate(raw).status, 'unavailable');
  });
  test(
    'capacity declaration and modern zero loss are checked independently',
    () {
      final raw = capture();
      expect(captureBudgetGate(raw).status, 'pass');
      object(raw['overflow'], 'overflow')['events'] = 1;
      expect(captureBudgetGate(raw).status, 'fail');
    },
  );
  test('each stream loss and unmatched native callback prevents a pass', () {
    for (final key in [
      'events',
      'layoutCosts',
      'resources',
      'frames',
      'motion',
      'native',
    ]) {
      final raw = capture();
      object(raw['overflow'], 'overflow')[key] = 1;
      expect(captureBudgetGate(raw).status, 'fail', reason: key);
    }
    final raw = capture();
    object(raw['presentation'], 'presentation')['unmatchedCallbacks'] = 1;
    expect(captureBudgetGate(raw).status, 'fail');
  });
  test(
    'missing native capability and undersized engine cannot be promoted',
    () {
      final raw = capture();
      final inventory = object(
        object(raw['presentation'], 'presentation')['inventory'],
        'inventory',
      );
      inventory.remove('captureBudgetVersion');
      expect(captureBudgetGate(raw).status, 'unavailable');
      inventory['captureBudgetVersion'] = 1;
      final metadata = object(
        object(raw['engine'], 'engine')['metadata'],
        'metadata',
      );
      object(metadata['readerCaptureBudget'], 'budget')['engineCapacity'] =
          65536;
      expect(captureBudgetGate(raw).status, 'unavailable');
    },
  );
  test('unknown versions are refused by tool and saved-record decoder', () {
    final raw = capture();
    final metadata = object(
      object(raw['engine'], 'engine')['metadata'],
      'metadata',
    );
    object(metadata['readerCaptureBudget'], 'budget')['version'] = 2;
    expect(() => captureBudgetGate(raw), throwsFormatException);
    expect(
      () => ReaderExportRepository.decode(jsonEncode(raw)),
      throwsA(isA<ParseException>()),
    );
  });
  test('capability cannot hide a missing prefix or forged envelope', () {
    final raw = capture();
    objects(raw['readerEvents'], 'events').first['sequence'] = 2;
    expect(captureBudgetGate(raw).status, 'fail');
    final metadata = object(
      object(raw['engine'], 'engine')['metadata'],
      'metadata',
    );
    object(metadata['readerCaptureBudget'], 'budget')['eventsPerFrame'] = 1;
    expect(() => captureBudgetGate(raw), throwsFormatException);
  });
}
