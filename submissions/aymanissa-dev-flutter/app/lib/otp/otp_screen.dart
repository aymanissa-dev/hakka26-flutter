import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hakka/otp/otp_code_input.dart';
import 'package:hakka/otp/otp_colors.dart';
import 'package:hakka/otp/otp_reducer.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.palettes});

  final OtpPalettes palettes;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  var _state = OtpState.initial();
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _apply(const OtpSecondElapsed());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _apply(OtpEvent event) {
    if (!mounted) return;
    final next = reduceOtp(_state, event);
    if (next == _state) return;
    setState(() => _state = next);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = widget.palettes.forBrightness(brightness);
    final dark = brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dimmedPage(colors),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Container(
            key: const Key('otp_sheet'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.sheet,
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              children: [
                Image.asset(
                  dark
                      ? 'assets/thamani-logo-white.png'
                      : 'assets/thamani-logo.png',
                  height: 56,
                  semanticLabel: 'Thamani logo',
                ),
                const SizedBox(height: 18),
                Text(
                  kTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  kSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 28),
                OtpCodeInput(
                  key: const Key('otp_code_input'),
                  digits: _state.digits,
                  focusIndex: _state.focusIndex,
                  colors: colors,
                  keyboardAppearance: brightness,
                  onEvent: _apply,
                ),
                const SizedBox(height: 16),
                _resend(colors),
                _status(colors),
                const Spacer(),
                _submit(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resend(OtpColors colors) {
    final ready = _state.resendSeconds <= 0;
    final label = resendLabel(_state.resendSeconds);
    final textStyle = TextStyle(
      fontSize: 14,
      height: 1.3,
      color: colors.textSecondary,
    );
    return Semantics(
      key: const Key('otp_resend'),
      identifier: 'otp_resend',
      button: true,
      enabled: ready,
      container: true,
      child: ready
          ? TextButton(
              onPressed: () => _apply(const OtpResendPressed()),
              style: TextButton.styleFrom(
                foregroundColor: colors.link,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text.rich(
                TextSpan(
                  style: textStyle,
                  children: [
                    TextSpan(
                      text: label.substring(0, label.length - 'Resend'.length),
                    ),
                    TextSpan(
                      text: 'Resend',
                      style: TextStyle(
                        color: colors.link,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(label, textAlign: TextAlign.center, style: textStyle),
            ),
    );
  }

  Widget _status(OtpColors colors) {
    final message = noticeMessage(_state.notice);
    final color = _state.notice == OtpNotice.success
        ? colors.success
        : colors.error;
    return Semantics(
      key: const Key('otp_status'),
      identifier: 'otp_status',
      liveRegion: message != null,
      container: true,
      child: SizedBox(
        height: 36,
        child: Center(
          child: Text(
            message ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _submit(OtpColors colors) {
    final enabled = _state.isComplete;
    return Semantics(
      identifier: 'otp_submit',
      button: true,
      enabled: enabled,
      container: true,
      child: FilledButton(
        key: const Key('otp_submit'),
        onPressed: enabled ? () => _apply(const OtpSubmitPressed()) : null,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.buttonDisabledBg;
            }
            return colors.buttonBg;
          }),
          foregroundColor: WidgetStateProperty.all(colors.buttonText),
          elevation: WidgetStateProperty.all(0),
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(52)),
          shape: WidgetStateProperty.all(const StadiumBorder()),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        child: const Text(kSubmitLabel),
      ),
    );
  }
}
