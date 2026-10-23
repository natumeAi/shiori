import 'package:flutter/material.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/l10n/l10n.dart';

class ReaderProbeSettings extends StatelessWidget {
  const ReaderProbeSettings({
    super.key,
    required this.settings,
    required this.reducedMotion,
    required this.onChanged,
    required this.onReducedMotion,
  });
  final ReaderSettings settings;
  final bool reducedMotion;
  final ValueChanged<ReaderSettings>? onChanged;
  final ValueChanged<bool>? onReducedMotion;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: settings.fontFamilyId,
          decoration: InputDecoration(labelText: l.readerFont),
          items: [
            for (final font in readerFontOptions)
              DropdownMenuItem(
                value: font.id,
                child: Text(l.readerFontName(font.id)),
              ),
          ],
          onChanged: onChanged == null
              ? null
              : (id) {
                  if (id != null) {
                    onChanged?.call(settings.copyWith(fontFamilyId: id));
                  }
                },
        ),
        _SettingSlider(
          label: l.readerSize,
          value: settings.fontSize,
          min: ReaderSettings.fontSizeMin,
          max: ReaderSettings.fontSizeMax,
          divisions: 13,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged?.call(settings.copyWith(fontSize: v)),
        ),
        _SettingSlider(
          label: l.readerLineHeight,
          value: settings.lineHeight,
          min: ReaderSettings.lineHeightMin,
          max: ReaderSettings.lineHeightMax,
          divisions: 7,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged?.call(settings.copyWith(lineHeight: v)),
        ),
        _SettingSlider(
          label: l.readerLetterSpacing,
          value: settings.letterSpacing,
          min: ReaderSettings.letterSpacingMin,
          max: ReaderSettings.letterSpacingMax,
          divisions: 6,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged?.call(settings.copyWith(letterSpacing: v)),
        ),
        _SettingSlider(
          label: l.readerHorizontalMargin,
          value: settings.horizontalMargin,
          min: ReaderSettings.horizontalMarginMin,
          max: ReaderSettings.horizontalMarginMax,
          divisions: 8,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged?.call(settings.copyWith(horizontalMargin: v)),
        ),
        _SettingSlider(
          label: l.readerVerticalMargin,
          value: settings.verticalMargin,
          min: ReaderSettings.verticalMarginMin,
          max: ReaderSettings.verticalMarginMax,
          divisions: 8,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged?.call(settings.copyWith(verticalMargin: v)),
        ),
        DropdownButtonFormField<String>(
          initialValue: settings.themeId,
          decoration: InputDecoration(labelText: l.readerTheme),
          items: [
            for (final theme in readerThemes)
              DropdownMenuItem(
                value: theme.id,
                child: Text(l.readerThemeName(theme.id)),
              ),
          ],
          onChanged: onChanged == null
              ? null
              : (id) {
                  if (id != null) {
                    onChanged?.call(settings.copyWith(themeId: id));
                  }
                },
        ),
        SwitchListTile(
          title: Text(l.readerReducedMotion),
          value: reducedMotion,
          onChanged: onReducedMotion,
        ),
      ],
    );
  }
}

class _SettingSlider extends StatefulWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double>? onChanged;
  @override
  State<_SettingSlider> createState() => _SettingSliderState();
}

class _SettingSliderState extends State<_SettingSlider> {
  double? _dragValue;
  @override
  Widget build(BuildContext context) {
    final value = _dragValue ?? widget.value;
    return Column(
      children: [
        Text(
          context.l10n.readerSettingValue(
            widget.label,
            value.toStringAsFixed(2),
          ),
        ),
        Slider(
          value: value,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          semanticFormatterCallback: (v) => context.l10n.readerSettingValue(
            widget.label,
            v.toStringAsFixed(2),
          ),
          onChanged: widget.onChanged == null
              ? null
              : (v) => setState(() => _dragValue = v),
          onChangeEnd: widget.onChanged == null
              ? null
              : (v) {
                  setState(() => _dragValue = null);
                  widget.onChanged?.call(v);
                },
        ),
      ],
    );
  }
}
