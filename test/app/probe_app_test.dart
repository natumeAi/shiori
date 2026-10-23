import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiori/app/probe_app.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/features/diagnostics/data/diagnostic_export_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_marker_repository.dart';
import 'package:shiori/features/diagnostics/presentation/diagnostics_screen.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_screen.dart';
import 'package:shiori/l10n/l10n.dart';

import '../helpers/probe_storage_fixtures.dart';

void main() {
  testWidgets(
    'probe home reaches unchanged S1 screen and the isolated reader route',
    (tester) async {
      final marker = MockMarkerRepository();
      final exports = MockExportRepository();
      when(marker.load).thenAnswer((_) async => '');
      when(exports.loadLast).thenAnswer((_) async => null);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            probeMarkerRepositoryProvider.overrideWith((ref) => marker),
            diagnosticExportRepositoryProvider.overrideWith((ref) => exports),
            appDirectoriesProvider.overrideWith(
              (ref) => TestDirectories(Directory.systemTemp),
            ),
          ],
          child: const ProbeApp(),
        ),
      );
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(const Locale('zh'));
      expect(find.text(l.probeSynthetic), findsOneWidget);
      expect(find.text(l.readerProbeTitle), findsOneWidget);
      await tester.tap(find.text(l.probeSynthetic));
      await tester.pumpAndSettle();
      expect(find.byType(DiagnosticsScreen), findsOneWidget);
      expect(find.text(l.diagnosticsEvidence), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.readerProbeTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ReaderProbeScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
      expect(tester.takeException(), isNull);
    },
  );
}
