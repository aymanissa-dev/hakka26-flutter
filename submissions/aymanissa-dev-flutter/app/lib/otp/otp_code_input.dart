import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hakka/otp/otp_colors.dart';
import 'package:hakka/otp/otp_reducer.dart';

/// Six circular digit boxes and the text fields that edit them.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    required this.digits,
    required this.focusIndex,
    required this.colors,
    required this.keyboardAppearance,
    required this.onEvent,
  });

  final List<String> digits;
  final int focusIndex;
  final OtpColors colors;
  final Brightness keyboardAppearance;
  final ValueChanged<OtpEvent> onEvent;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  final _controllers = List.generate(
    kOtpLength,
    (_) => TextEditingController(),
  );
  final _nodes = List.generate(kOtpLength, (_) => FocusNode());
  var _suppress = false;
  var _revision = 0;
  var _syncRevision = 0;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < kOtpLength; i++) {
      final index = i;
      _nodes[i].onKeyEvent = (node, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.backspace) {
          return KeyEventResult.ignored;
        }
        if (_controllers[index].text.isNotEmpty ||
            widget.digits[index].isNotEmpty) {
          return KeyEventResult.ignored;
        }
        widget.onEvent(OtpBackspacePressed(index));
        return KeyEventResult.handled;
      };
    }
  }

  @override
  void didUpdateWidget(OtpCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final digitsChanged = !_sameDigits(oldWidget.digits, widget.digits);
    final focusChanged = oldWidget.focusIndex != widget.focusIndex;
    _scheduleSync(writeText: digitsChanged || focusChanged);
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _sameDigits(List<String> previous, List<String> next) {
    for (var i = 0; i < kOtpLength; i++) {
      if (previous[i] != next[i]) return false;
    }
    return true;
  }

  void _onChanged(int index, String value) {
    if (_suppress) return;
    final revision = ++_revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _revision) return;
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length > 1) {
        widget.onEvent(OtpTextPasted(index, digits));
      } else if (digits.length == 1) {
        widget.onEvent(OtpDigitTyped(index, digits));
      } else if (widget.digits[index].isNotEmpty) {
        widget.onEvent(OtpBackspacePressed(index));
      }
    });
  }

  void _scheduleSync({required bool writeText}) {
    final revision = ++_syncRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _syncRevision) return;
      if (writeText) {
        _syncControllers(widget.digits, widget.focusIndex);
      }
      final node = _nodes[widget.focusIndex];
      if (!node.hasFocus) node.requestFocus();
    });
  }

  void _syncControllers(List<String> digits, int focusIndex) {
    _suppress = true;
    for (var i = 0; i < kOtpLength; i++) {
      final digit = digits[i];
      final controller = _controllers[i];
      final selection = i == focusIndex
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
              OtpDigitBox(
                id: 'otp_digit_${i + 1}',
                label: digitSemanticsLabel(i),
                value: widget.digits[i],
                controller: _controllers[i],
                focusNode: _nodes[i],
                colors: widget.colors,
                focused: widget.focusIndex == i,
                diameter: diameter,
                autofocus: i == 0,
                keyboardAppearance: widget.keyboardAppearance,
                onChanged: (value) => _onChanged(i, value),
                onTap: () => widget.onEvent(OtpBoxFocused(i)),
              ),
            ],
          ],
        );
      },
    );
  }
}

class OtpDigitBox extends StatelessWidget {
  const OtpDigitBox({
    super.key,
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
        child: Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              selectionColor: background,
              selectionHandleColor: colors.textPrimary,
            ),
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
      ),
    );
  }
}
