enum OtpNotice { none, success, error }

const kOtpLength = 6;
const kCountdownSeconds = 30;
const kSuccessCode = '123456';

const kTitle = 'Enter your code';
const kSubtitle = 'A 6-digit code has been sent to your phone.';
const kSubmitLabel = 'Submit';
const kSuccessMessage = "You're in.";
const kErrorMessage = "That code didn't work. Try again.";
const kResendReady = "Didn't receive the code? Resend";
const kPlaceholder = '\u2013';

class OtpState {
  OtpState({
    required List<String> digits,
    required this.focusIndex,
    required this.notice,
    required this.resendSeconds,
  }) : digits = List.unmodifiable(digits) {
    if (digits.length != kOtpLength) {
      throw ArgumentError.value(
        digits.length,
        'digits',
        'expected $kOtpLength',
      );
    }
  }

  factory OtpState.initial() {
    return OtpState(
      digits: List.filled(kOtpLength, ''),
      focusIndex: 0,
      notice: OtpNotice.none,
      resendSeconds: kCountdownSeconds,
    );
  }

  final List<String> digits;
  final int focusIndex;
  final OtpNotice notice;
  final int resendSeconds;

  bool get isComplete => digits.every((digit) => digit.length == 1);

  String get code => digits.join();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OtpState ||
        other.focusIndex != focusIndex ||
        other.notice != notice ||
        other.resendSeconds != resendSeconds) {
      return false;
    }
    for (var i = 0; i < kOtpLength; i++) {
      if (other.digits[i] != digits[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(focusIndex, notice, resendSeconds, Object.hashAll(digits));
}

sealed class OtpEvent {
  const OtpEvent();
}

class OtpDigitTyped extends OtpEvent {
  const OtpDigitTyped(this.index, this.digit);
  final int index;
  final String digit;
}

class OtpBackspacePressed extends OtpEvent {
  const OtpBackspacePressed(this.index);
  final int index;
}

class OtpTextPasted extends OtpEvent {
  const OtpTextPasted(this.index, this.text);
  final int index;
  final String text;
}

class OtpSubmitPressed extends OtpEvent {
  const OtpSubmitPressed();
}

class OtpSecondElapsed extends OtpEvent {
  const OtpSecondElapsed();
}

class OtpResendPressed extends OtpEvent {
  const OtpResendPressed();
}

class OtpBoxFocused extends OtpEvent {
  const OtpBoxFocused(this.index);
  final int index;
}

String resendLabel(int secondsRemaining) {
  if (secondsRemaining <= 0) return kResendReady;
  final minutes = secondsRemaining ~/ 60;
  final seconds = (secondsRemaining % 60).toString().padLeft(2, '0');
  return 'Resend in $minutes:$seconds';
}

String digitSemanticsLabel(int index) => 'Digit ${index + 1} of $kOtpLength';

String? noticeMessage(OtpNotice notice) {
  return switch (notice) {
    OtpNotice.none => null,
    OtpNotice.success => kSuccessMessage,
    OtpNotice.error => kErrorMessage,
  };
}

OtpState reduceOtp(OtpState state, OtpEvent event) {
  return switch (event) {
    OtpDigitTyped(:final index, :final digit) => _typeDigit(
      state,
      index,
      digit,
    ),
    OtpBackspacePressed(:final index) => _backspace(state, index),
    OtpTextPasted(:final index, :final text) => _paste(state, index, text),
    OtpSubmitPressed() => _submit(state),
    OtpSecondElapsed() => _tick(state),
    OtpResendPressed() => _resend(state),
    OtpBoxFocused(:final index) => _focus(state, index),
  };
}

bool _inRange(int index) => index >= 0 && index < kOtpLength;

OtpState _typeDigit(OtpState state, int index, String digit) {
  if (!_inRange(index) || !_isDigit(digit)) return state;
  final next = List<String>.of(state.digits);
  next[index] = digit;
  return OtpState(
    digits: next,
    focusIndex: index < kOtpLength - 1 ? index + 1 : index,
    notice: OtpNotice.none,
    resendSeconds: state.resendSeconds,
  );
}

OtpState _backspace(OtpState state, int index) {
  if (!_inRange(index)) return state;
  final next = List<String>.of(state.digits);
  if (next[index].isNotEmpty) {
    next[index] = '';
    return OtpState(
      digits: next,
      focusIndex: index,
      notice: OtpNotice.none,
      resendSeconds: state.resendSeconds,
    );
  }
  if (index == 0) return state;
  next[index - 1] = '';
  return OtpState(
    digits: next,
    focusIndex: index - 1,
    notice: OtpNotice.none,
    resendSeconds: state.resendSeconds,
  );
}

OtpState _paste(OtpState state, int index, String text) {
  if (!_inRange(index)) return state;
  final extracted = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (extracted.isEmpty) return state;
  final next = List<String>.of(state.digits);
  var cursor = index;
  for (final char in extracted.split('')) {
    if (cursor >= kOtpLength) break;
    next[cursor] = char;
    cursor += 1;
  }
  return OtpState(
    digits: next,
    focusIndex: cursor >= kOtpLength ? kOtpLength - 1 : cursor,
    notice: OtpNotice.none,
    resendSeconds: state.resendSeconds,
  );
}

OtpState _submit(OtpState state) {
  if (!state.isComplete) return state;
  if (state.code == kSuccessCode) {
    return OtpState(
      digits: state.digits,
      focusIndex: state.focusIndex,
      notice: OtpNotice.success,
      resendSeconds: state.resendSeconds,
    );
  }
  return OtpState(
    digits: List.filled(kOtpLength, ''),
    focusIndex: 0,
    notice: OtpNotice.error,
    resendSeconds: state.resendSeconds,
  );
}

OtpState _tick(OtpState state) {
  if (state.resendSeconds <= 0) return state;
  return OtpState(
    digits: state.digits,
    focusIndex: state.focusIndex,
    notice: state.notice,
    resendSeconds: state.resendSeconds - 1,
  );
}

OtpState _resend(OtpState state) {
  if (state.resendSeconds > 0) return state;
  return OtpState(
    digits: state.digits,
    focusIndex: state.focusIndex,
    notice: state.notice,
    resendSeconds: kCountdownSeconds,
  );
}

OtpState _focus(OtpState state, int index) {
  if (!_inRange(index) || index == state.focusIndex) return state;
  return OtpState(
    digits: state.digits,
    focusIndex: index,
    notice: state.notice,
    resendSeconds: state.resendSeconds,
  );
}

bool _isDigit(String value) => value.length == 1 && int.tryParse(value) != null;
