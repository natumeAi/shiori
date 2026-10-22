import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';

void main() {
  group('font size', () {
    test('clamps to 14-40 and snaps to the 2 px grid', () {
      expect(ReaderSettings.clampFontSize(18), 18);
      expect(ReaderSettings.clampFontSize(5), 14);
      expect(ReaderSettings.clampFontSize(99), 40);
      expect(ReaderSettings.clampFontSize(19), 20); // Math.round(2.5) = 3
      expect(ReaderSettings.clampFontSize(18.9), 18);
      expect(ReaderSettings.clampFontSize(21), 22);
    });

    test('non-numeric and non-finite input yields the default', () {
      expect(ReaderSettings.clampFontSize(double.nan), 18);
      expect(ReaderSettings.clampFontSize(double.infinity), 18);
      expect(ReaderSettings.clampFontSize('abc'), 18);
      expect(ReaderSettings.clampFontSize(const <Object?>[]), 18);
    });

    test('numeric strings follow JavaScript Number()', () {
      expect(ReaderSettings.clampFontSize('24'), 24);
      expect(ReaderSettings.clampFontSize(' 24 '), 24);
      // Number('') and Number(null) are 0, then clamped up.
      expect(ReaderSettings.clampFontSize(''), 14);
      expect(ReaderSettings.clampFontSize(null), 14);
      expect(ReaderSettings.clampFontSize(true), 14);
    });
  });

  group('margins', () {
    test('clamp to 0-48 without snapping', () {
      expect(ReaderSettings.clampHorizontalMargin(7), 7);
      expect(ReaderSettings.clampHorizontalMargin(-3), 0);
      expect(ReaderSettings.clampHorizontalMargin(80), 48);
      expect(ReaderSettings.clampVerticalMargin(20.5), 20.5);
      expect(ReaderSettings.clampVerticalMargin(double.nan), 0);
    });

    test('effective margins add the reference bases', () {
      const settings = ReaderSettings(horizontalMargin: 12, verticalMargin: 6);
      expect(settings.effectiveHorizontalMargin, 60);
      expect(settings.effectiveVerticalMargin, 66);
      expect(const ReaderSettings().effectiveHorizontalMargin, 48);
      expect(const ReaderSettings().effectiveVerticalMargin, 60);
    });
  });

  group('line height and letter spacing', () {
    test('line height clamps to 1.3-2.0 and rounds to one decimal', () {
      expect(ReaderSettings.clampLineHeight(1.6), 1.6);
      expect(ReaderSettings.clampLineHeight(1.0), 1.3);
      expect(ReaderSettings.clampLineHeight(3), 2.0);
      expect(ReaderSettings.clampLineHeight(1.74), 1.7);
      expect(ReaderSettings.clampLineHeight(1.76), 1.8);
      expect(ReaderSettings.clampLineHeight('x'), 1.6);
    });

    test('letter spacing clamps to 0-0.12 and rounds to two decimals', () {
      expect(ReaderSettings.clampLetterSpacing(0.02), 0.02);
      expect(ReaderSettings.clampLetterSpacing(-1), 0);
      expect(ReaderSettings.clampLetterSpacing(1), 0.12);
      expect(ReaderSettings.clampLetterSpacing(0.057), 0.06);
      expect(ReaderSettings.clampLetterSpacing(double.nan), 0);
    });
  });

  group('identifiers', () {
    test('unknown font and theme ids fall back to the defaults', () {
      expect(ReaderSettings.sanitizeFontFamilyId('kai'), 'kai');
      expect(ReaderSettings.sanitizeFontFamilyId('comic'), 'system');
      expect(ReaderSettings.sanitizeFontFamilyId(3), 'system');
      expect(ReaderSettings.sanitizeThemeId('dark'), 'dark');
      expect(ReaderSettings.sanitizeThemeId('pink'), 'light');
      expect(ReaderSettings.sanitizeThemeId(null), 'light');
    });

    test('fontOption and theme resolve like the reference lookups', () {
      expect(const ReaderSettings(fontFamilyId: 'kai').fontOption.id, 'kai');
      expect(
        const ReaderSettings(fontFamilyId: 'nope').fontOption.id,
        'system',
      );
      expect(
        const ReaderSettings(themeId: 'warm').theme.background,
        0xFFF4ECD9,
      );
      expect(const ReaderSettings(themeId: 'nope').theme.id, 'light');
    });
  });

  group('sanitize', () {
    test('non-object input yields the defaults', () {
      expect(ReaderSettings.sanitize(null), const ReaderSettings());
      expect(ReaderSettings.sanitize('x'), const ReaderSettings());
      expect(ReaderSettings.sanitize(<Object?>[1]), const ReaderSettings());
    });

    test('sanitizes every field of a decoded JSON object', () {
      final settings = ReaderSettings.sanitize({
        'fontSize': 33,
        'fontFamilyId': 'serif',
        'horizontalMargin': 100,
        'verticalMargin': -4,
        'lineHeight': 1.84,
        'letterSpacing': 0.049,
        'themeId': 'green',
      });
      expect(
        settings,
        const ReaderSettings(
          fontSize: 34,
          fontFamilyId: 'serif',
          horizontalMargin: 48,
          verticalMargin: 0,
          lineHeight: 1.8,
          letterSpacing: 0.05,
          themeId: 'green',
        ),
      );
    });

    test('a missing key is the default, an explicit null coerces to 0', () {
      expect(ReaderSettings.sanitize({}).fontSize, 18);
      expect(ReaderSettings.sanitize({'fontSize': null}).fontSize, 14);
    });

    test('toJson round-trips through sanitize and sanitizes values', () {
      const settings = ReaderSettings(fontSize: 26, lineHeight: 2.0);
      expect(ReaderSettings.sanitize(settings.toJson()), settings);
      expect(const ReaderSettings(fontSize: 99).toJson()['fontSize'], 40);
      expect(const ReaderSettings(fontSize: 99).sanitized().fontSize, 40);
    });
  });
}
