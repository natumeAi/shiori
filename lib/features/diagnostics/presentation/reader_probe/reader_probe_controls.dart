import 'package:flutter/material.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
import 'package:shiori/features/diagnostics/data/presentation_probe.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_controller.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_settings.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_scenario_runner.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/l10n/l10n.dart';

class ReaderProbeControls extends StatelessWidget {
  const ReaderProbeControls({
    super.key,
    required this.controller,
    required this.busy,
    required this.scenario,
    required this.repeats,
    required this.manual,
    required this.declarations,
    required this.model,
    required this.mode,
    required this.onScenario,
    required this.onRepeats,
    required this.onManual,
    required this.onDeclarations,
    required this.onMode,
    required this.onSettings,
    required this.onReducedMotion,
    required this.onJump,
    required this.onBooks,
  });
  final ReaderProbeController controller;
  final bool busy, manual;
  final String scenario;
  final int repeats;
  final ProbeDeclarations declarations;
  final TextEditingController model;
  final PresentationMode mode;
  final ValueChanged<String> onScenario;
  final ValueChanged<int> onRepeats;
  final ValueChanged<bool> onManual;
  final ValueChanged<ProbeDeclarations> onDeclarations;
  final ValueChanged<PresentationMode> onMode;
  final ValueChanged<ReaderSettings> onSettings;
  final ValueChanged<bool> onReducedMotion;
  final ValueChanged<int> onJump;
  final VoidCallback onBooks;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.readerProbeControls,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(l.readerProbeHelp),
        OutlinedButton(
          onPressed: busy ? null : onBooks,
          child: Text(l.readerBooks),
        ),
        DropdownButtonFormField<String>(
          itemHeight: null,
          initialValue: scenario,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.readerScenario),
          items: [
            for (final id in ReaderScenarioRunner.fixtures.keys)
              DropdownMenuItem(
                value: id,
                child: Text(l.readerScenarioName(id), maxLines: 3),
              ),
          ],
          onChanged: busy
              ? null
              : (id) {
                  if (id != null) onScenario(id);
                },
        ),
        DropdownButtonFormField<int>(
          isExpanded: true,
          itemHeight: null,
          initialValue: repeats,
          decoration: InputDecoration(labelText: l.readerRepeat),
          items: [
            for (final n in [1, 3, 5, 10])
              DropdownMenuItem(value: n, child: Text('$n')),
          ],
          onChanged: busy || scenario == 'R11'
              ? null
              : (n) {
                  if (n != null) onRepeats(n);
                },
        ),
        SwitchListTile(
          title: Text(l.readerManual),
          value: manual || scenario == 'R11',
          onChanged: busy || scenario == 'R11' ? null : onManual,
        ),
        if (scenario == 'R11') Text(l.readerManualMinimum),
        TextField(
          controller: model,
          enabled: !busy,
          decoration: InputDecoration(labelText: l.diagnosticsDeviceModel),
        ),
        for (final (label, value, apply)
            in <(String, DeclaredSetting, void Function(DeclaredSetting))>[
              (
                l.diagnosticsLowPower,
                declarations.lowPowerMode,
                (v) => onDeclarations(declarations.copyWith(lowPowerMode: v)),
              ),
              (
                l.diagnosticsLimitRate,
                declarations.limitFrameRate,
                (v) => onDeclarations(declarations.copyWith(limitFrameRate: v)),
              ),
              (
                l.diagnosticsCharging,
                declarations.charging,
                (v) => onDeclarations(declarations.copyWith(charging: v)),
              ),
              (
                l.diagnosticsWarm,
                declarations.warm,
                (v) => onDeclarations(declarations.copyWith(warm: v)),
              ),
            ])
          DropdownButtonFormField<DeclaredSetting>(
            isExpanded: true,
            itemHeight: null,
            initialValue: value,
            decoration: InputDecoration(labelText: label),
            items: [
              for (final v in DeclaredSetting.values)
                DropdownMenuItem(
                  value: v,
                  child: Text(switch (v) {
                    DeclaredSetting.on => l.diagnosticsOn,
                    DeclaredSetting.off => l.diagnosticsOff,
                    DeclaredSetting.unknown => l.diagnosticsUnknown,
                  }),
                ),
            ],
            onChanged: busy
                ? null
                : (v) {
                    if (v != null) apply(v);
                  },
          ),
        DropdownButtonFormField<PresentationMode>(
          isExpanded: true,
          itemHeight: null,
          initialValue: mode,
          decoration: InputDecoration(labelText: l.readerNativeMode),
          items: [
            for (final v in PresentationMode.values)
              DropdownMenuItem(
                value: v,
                child: Text(l.readerNativeModeName(v.name)),
              ),
          ],
          onChanged: busy
              ? null
              : (v) {
                  if (v != null) onMode(v);
                },
        ),
        ReaderProbeSettings(
          key: ValueKey(controller.settings),
          settings: controller.settings,
          reducedMotion: controller.reducedMotion,
          onChanged: busy ? null : onSettings,
          onReducedMotion: busy ? null : onReducedMotion,
        ),
        if (controller.sectionCount > 0)
          DropdownButtonFormField<int>(
            isExpanded: true,
            itemHeight: null,
            key: ValueKey(controller.turn),
            initialValue: controller.turn?.accepted.sectionIndex,
            decoration: InputDecoration(labelText: l.readerJump),
            items: [
              for (var i = 0; i < controller.sectionCount; i++)
                DropdownMenuItem(value: i, child: Text(l.readerSection(i + 1))),
            ],
            onChanged: busy
                ? null
                : (v) {
                    if (v != null) onJump(v);
                  },
          ),
      ],
    );
  }
}
