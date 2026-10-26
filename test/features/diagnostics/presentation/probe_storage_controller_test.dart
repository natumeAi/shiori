import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/diagnostic_export_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_marker_repository.dart';
import 'package:shiori/features/diagnostics/presentation/probe_storage_controller.dart';

import '../../../helpers/probe_storage_fixtures.dart';

void main() {
  late MockMarkerRepository marker;
  late MockExportRepository exports;
  late ProviderContainer container;
  setUp(() {
    marker = MockMarkerRepository();
    exports = MockExportRepository();
    when(marker.load).thenAnswer((_) async => 'retained');
    when(exports.loadLast).thenAnswer((_) async => storageRecord());
    when(() => marker.save(any())).thenAnswer((_) async {});
    container = ProviderContainer.test(
      overrides: [
        probeMarkerRepositoryProvider.overrideWith((ref) => marker),
        diagnosticExportRepositoryProvider.overrideWith((ref) => exports),
      ],
      retry: (_, _) => null,
    );
    container.listen(probeStorageControllerProvider, (_, _) {});
  });
  test('loads retained marker and last record, saves edited marker', () async {
    final initial = await container.read(probeStorageControllerProvider.future);
    expect(initial.marker, 'retained');
    expect(initial.lastRecord, storageRecord());
    await container
        .read(probeStorageControllerProvider.notifier)
        .saveMarker('new');
    expect(
      container.read(probeStorageControllerProvider).requireValue.marker,
      'new',
    );
    verify(() => marker.save('new')).called(1);
  });
  test(
    'load errors become AsyncError, mutation errors preserve loaded state',
    () async {
      await container.read(probeStorageControllerProvider.future);
      when(() => marker.save(any())).thenThrow(const ParseException());
      await expectLater(
        container
            .read(probeStorageControllerProvider.notifier)
            .saveMarker('new'),
        throwsA(isA<ParseException>()),
      );
      expect(
        container.read(probeStorageControllerProvider).requireValue.marker,
        'retained',
      );
      when(exports.loadLast).thenThrow(const ParseException());
      container.invalidate(probeStorageControllerProvider);
      await expectLater(
        container.read(probeStorageControllerProvider.future),
        throwsA(isA<ParseException>()),
      );
      expect(container.read(probeStorageControllerProvider).hasError, isTrue);
    },
  );
  test('marker load failure propagates without reading last record', () async {
    when(marker.load).thenThrow(const ParseException());
    container.invalidate(probeStorageControllerProvider);
    await expectLater(
      container.read(probeStorageControllerProvider.future),
      throwsA(isA<ParseException>()),
    );
  });
  test(
    'save completing after provider disposal does not touch disposed ref',
    () async {
      await container.read(probeStorageControllerProvider.future);
      final pending = Completer<void>();
      when(() => marker.save(any())).thenAnswer((_) => pending.future);
      final operation = container
          .read(probeStorageControllerProvider.notifier)
          .saveMarker('later');
      container.invalidate(probeStorageControllerProvider);
      pending.complete();
      await operation;
    },
  );
}
