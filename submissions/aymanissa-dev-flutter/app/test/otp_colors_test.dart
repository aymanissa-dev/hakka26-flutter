import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakka/otp/otp_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('light and dark colours come from colours.json', () async {
    final raw = await rootBundle.loadString('assets/colours.json');
    final root = jsonDecode(raw) as Map<String, dynamic>;
    final otp = root['otp'] as Map<String, dynamic>;
    final palettes = await OtpPalettes.load();

    void expectMode(OtpColors colors, Map<String, dynamic> json) {
      expect(colors.sheet, OtpColors.parseHex(json['sheet'] as String));
      expect(colors.scrim, OtpColors.parseHex(json['scrim'] as String));
      expect(
        colors.textPrimary,
        OtpColors.parseHex(json['text_primary'] as String),
      );
      expect(
        colors.textSecondary,
        OtpColors.parseHex(json['text_secondary'] as String),
      );
      expect(
        colors.digitFilledBg,
        OtpColors.parseHex(json['digit_filled_bg'] as String),
      );
      expect(
        colors.digitFilledText,
        OtpColors.parseHex(json['digit_filled_text'] as String),
      );
      expect(
        colors.digitFocusedBg,
        OtpColors.parseHex(json['digit_focused_bg'] as String),
      );
      expect(
        colors.digitFocusedOutline,
        OtpColors.parseHex(json['digit_focused_outline'] as String),
      );
      expect(
        colors.digitEmptyBg,
        OtpColors.parseHex(json['digit_empty_bg'] as String),
      );
      expect(
        colors.digitEmptyOutline,
        OtpColors.parseHex(json['digit_empty_outline'] as String),
      );
      expect(
        colors.digitPlaceholder,
        OtpColors.parseHex(json['digit_placeholder'] as String),
      );
      expect(colors.buttonBg, OtpColors.parseHex(json['button_bg'] as String));
      expect(
        colors.buttonText,
        OtpColors.parseHex(json['button_text'] as String),
      );
      expect(
        colors.buttonDisabledBg,
        OtpColors.parseHex(json['button_disabled_bg'] as String),
      );
      expect(colors.link, OtpColors.parseHex(json['link'] as String));
      expect(colors.success, OtpColors.parseHex(json['success'] as String));
      expect(colors.error, OtpColors.parseHex(json['error'] as String));
      for (final key in OtpColors.keys) {
        expect(json.containsKey(key), isTrue, reason: 'missing $key');
      }
    }

    expectMode(palettes.light, otp['light'] as Map<String, dynamic>);
    expectMode(palettes.dark, otp['dark'] as Map<String, dynamic>);
    expect(palettes.light.sheet, isNot(palettes.dark.sheet));
    expect(palettes.light.digitFilledBg, isNot(palettes.dark.digitFilledBg));
    expect(palettes.light.scrim.a, lessThan(1));
    expect(palettes.dark.scrim.a, lessThan(1));
    expect(palettes.light.sheet.a, 1);
  });

  test('a missing colour key fails instead of inventing a fallback', () {
    final json = {for (final key in OtpColors.keys) key: '#112233'};
    json.remove('link');
    expect(() => OtpColors.fromJson(json), throwsFormatException);
  });

  test('malformed colour values are rejected', () {
    final json = {for (final key in OtpColors.keys) key: '#112233'};
    json['sheet'] = '112233';
    expect(() => OtpColors.fromJson(json), throwsFormatException);
    json['sheet'] = '#GGHHII';
    expect(() => OtpColors.fromJson(json), throwsFormatException);
    json['sheet'] = '#1234';
    expect(() => OtpColors.fromJson(json), throwsFormatException);
  });

  test('the dimmed page composites the scrim over the sheet', () async {
    final palettes = await OtpPalettes.load();
    expect(
      dimmedPage(palettes.light),
      Color.alphaBlend(palettes.light.scrim, palettes.light.sheet),
    );
    expect(
      dimmedPage(palettes.dark),
      Color.alphaBlend(palettes.dark.scrim, palettes.dark.sheet),
    );
  });
}
