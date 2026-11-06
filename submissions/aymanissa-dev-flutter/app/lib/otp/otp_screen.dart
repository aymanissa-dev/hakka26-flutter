import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hakka/otp/otp_colors.dart';
import 'package:hakka/otp/otp_reducer.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.palettes});

  final OtpPalettes palettes;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controllers = List.generate(
    kOtpLength,
    (_) => TextEditingController(),
  );
  final _nodes = List.generate(kOtpLength, (_) => FocusNode());
  var _state = OtpState.initial();
  var _suppress = false;
  var _revision = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _apply(const OtpSecondElapsed());
    });
    for (var i = 0; i < kOtpLength; i++) {
      final index = i;
      _nodes[i].onKeyEvent = (node, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.backspace) {
          return KeyEventResult.ignored;
        }
        if (_controllers[index].text.isNotEmpty ||
            _state.digits[index].isNotEmpty) {
          return KeyEventResult.ignored;
        }
        _apply(OtpBackspacePressed(index));
        return KeyEventResult.handled;
      };
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    for (final node in _nodes) {
      node.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (_suppress) return;
    final revision = ++_revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _revision) return;
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length > 1) {
        _apply(OtpTextPasted(index, digits));
      } else if (digits.length == 1) {
        _apply(OtpDigitTyped(index, digits));
      } else if (_state.digits[index].isNotEmpty) {
        _apply(OtpBackspacePressed(index));
      }
    });
  }

  void _apply(OtpEvent event) {
    if (!mounted) return;
    final next = reduceOtp(_state, event);
    if (next == _state) return;
    setState(() => _state = next);
    _syncControllers(next);
    final node = _nodes[next.focusIndex];
    if (!node.hasFocus) node.requestFocus();
  }

  void _syncControllers(OtpState next) {
    _suppress = true;
    for (var i = 0; i < kOtpLength; i++) {
      final digit = next.digits[i];
      final controller = _controllers[i];
      final selection = i == next.focusIndex
          ? TextSelection(baseOffset: 0, extentOffset: digit.length)
          : TextSelection.collapsed(offset: digit.length);
      if (controller.text != digit || controller.selection != selection) {
        controller.value = TextEditingValue(text: digit, selection: selection);
      }
    }
    _suppress = false;
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
                _digitRow(colors, brightness),
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

  Widget _digitRow(OtpColors colors, Brightness brightness) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final diameter =
            ((constraints.maxWidth - gap * (kOtpLength - 1)) / kOtpLength)
                .clamp(36.0, 52.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < kOtpLength; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              _DigitBox(
                id: 'otp_digit_${i + 1}',
                label: digitSemanticsLabel(i),
                value: _state.digits[i],
                controller: _controllers[i],
                focusNode: _nodes[i],
                colors: colors,
                focused: _state.focusIndex == i,
                diameter: diameter,
                autofocus: i == 0,
                keyboardAppearance: brightness,
                onChanged: (value) => _onChanged(i, value),
                onTap: () => _apply(OtpBoxFocused(i)),
              ),
            ],
          ],
        );
      },
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

class _DigitBox extends StatelessWidget {
  const _DigitBox({
    required this.id,
    required this.label,
    required this.value,
    required this.controller,
    required this.focusNode,
    required this.colors,
    required this.focused,
    required this.diameter,
    required this.autofocus,
    required this.keyboardAppearance,
    required this.onChanged,
    required this.onTap,
  });

  final String id;
  final String label;
  final String value;
  final TextEditingController controller;
  final FocusNode focusNode;
  final OtpColors colors;
  final bool focused;
  final double diameter;
  final bool autofocus;
  final Brightness keyboardAppearance;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = value.isNotEmpty;
    final background = focused
        ? colors.digitFocusedBg
        : filled
        ? colors.digitFilledBg
        : colors.digitEmptyBg;
    final border = focused
        ? colors.digitFocusedOutline
        : filled
        ? colors.digitFilledBg
        : colors.digitEmptyOutline;
    final textColor = !filled
        ? colors.textPrimary
        : focused
        ? colors.textPrimary
        : colors.digitFilledText;
    final fontSize = diameter * 0.42;
    return Semantics(
      identifier: id,
      label: label,
      value: value,
      textField: true,
      focusable: true,
      focused: focused,
      container: true,
      excludeSemantics: true,
      child: Container(
        key: Key(id),
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: focused ? 1.8 : 1.2),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          keyboardType: TextInputType.number,
          keyboardAppearance: keyboardAppearance,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          expands: true,
          maxLines: null,
          enableSuggestions: false,
          autocorrect: false,
          showCursor: false,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            counterText: '',
            contentPadding: EdgeInsets.zero,
            hintText: filled || focused ? null : kPlaceholder,
            hintStyle: TextStyle(
              color: colors.digitPlaceholder,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          onChanged: onChanged,
          onTap: onTap,
        ),
      ),
    );
  }
}
