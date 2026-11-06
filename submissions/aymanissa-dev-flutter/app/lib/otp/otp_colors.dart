import 'dart:convert';

import 'package:flutter/services.dart';

class OtpPalettes {
  const OtpPalettes({required this.light, required this.dark});

  final OtpColors light;
  final OtpColors dark;

  OtpColors forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static Future<OtpPalettes> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString('assets/colours.json');
    final decoded = jsonDecode(raw);
    final root = _asMap(decoded, 'root');
    final otp = _asMap(root['otp'], 'otp');
    return OtpPalettes(
      light: OtpColors.fromJson(_asMap(otp['light'], 'otp.light')),
      dark: OtpColors.fromJson(_asMap(otp['dark'], 'otp.dark')),
    );
  }
}

class OtpColors {
  const OtpColors({
    required this.sheet,
    required this.scrim,
    required this.textPrimary,
    required this.textSecondary,
    required this.digitFilledBg,
    required this.digitFilledText,
    required this.digitFocusedBg,
    required this.digitFocusedOutline,
    required this.digitEmptyBg,
    required this.digitEmptyOutline,
    required this.digitPlaceholder,
    required this.buttonBg,
    required this.buttonText,
    required this.buttonDisabledBg,
    required this.link,
    required this.success,
    required this.error,
  });

  final Color sheet;
  final Color scrim;
  final Color textPrimary;
  final Color textSecondary;
  final Color digitFilledBg;
  final Color digitFilledText;
  final Color digitFocusedBg;
  final Color digitFocusedOutline;
  final Color digitEmptyBg;
  final Color digitEmptyOutline;
  final Color digitPlaceholder;
  final Color buttonBg;
  final Color buttonText;
  final Color buttonDisabledBg;
  final Color link;
  final Color success;
  final Color error;

  static const keys = <String>[
    'sheet',
    'scrim',
    'text_primary',
    'text_secondary',
    'digit_filled_bg',
    'digit_filled_text',
    'digit_focused_bg',
    'digit_focused_outline',
    'digit_empty_bg',
    'digit_empty_outline',
    'digit_placeholder',
    'button_bg',
    'button_text',
    'button_disabled_bg',
    'link',
    'success',
    'error',
  ];

  factory OtpColors.fromJson(Map<String, dynamic> json) {
    Color take(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('colours.json is missing "$key"');
      }
      return parseHex(value);
    }

    return OtpColors(
      sheet: take('sheet'),
      scrim: take('scrim'),
      textPrimary: take('text_primary'),
      textSecondary: take('text_secondary'),
      digitFilledBg: take('digit_filled_bg'),
      digitFilledText: take('digit_filled_text'),
      digitFocusedBg: take('digit_focused_bg'),
      digitFocusedOutline: take('digit_focused_outline'),
      digitEmptyBg: take('digit_empty_bg'),
      digitEmptyOutline: take('digit_empty_outline'),
      digitPlaceholder: take('digit_placeholder'),
      buttonBg: take('button_bg'),
      buttonText: take('button_text'),
      buttonDisabledBg: take('button_disabled_bg'),
      link: take('link'),
      success: take('success'),
      error: take('error'),
    );
  }

  static Color parseHex(String input) {
    final hex = input.trim();
    if (!hex.startsWith('#')) {
      throw FormatException('Colour "$input" must start with #');
    }
    final body = hex.substring(1);
    if (body.length != 6 && body.length != 8) {
      throw FormatException('Colour "$input" must be #RRGGBB or #AARRGGBB');
    }
    final parsed = int.tryParse(body, radix: 16);
    if (parsed == null) {
      throw FormatException('Colour "$input" is not hexadecimal');
    }
    final value = body.length == 6 ? (0xFF000000 | parsed) : parsed;
    return Color(value);
  }
}

Color dimmedPage(OtpColors colors) =>
    Color.alphaBlend(colors.scrim, colors.sheet);

Map<String, dynamic> _asMap(Object? value, String name) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  throw FormatException('colours.json is missing $name');
}
