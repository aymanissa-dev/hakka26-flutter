import 'package:flutter_test/flutter_test.dart';
import 'package:hakka/otp/otp_reducer.dart';

void main() {
  OtpState typeCode(String code) {
    var state = OtpState.initial();
    for (var i = 0; i < code.length; i++) {
      state = reduceOtp(state, OtpDigitTyped(i, code[i]));
    }
    return state;
  }

  test('initial state is empty, focused, and counting down', () {
    final state = OtpState.initial();
    expect(state.digits, List.filled(kOtpLength, ''));
    expect(state.focusIndex, 0);
    expect(state.notice, OtpNotice.none);
    expect(state.resendSeconds, kCountdownSeconds);
    expect(state.isComplete, isFalse);
  });

  test('typing a digit fills the box and moves to the next', () {
    final state = reduceOtp(OtpState.initial(), const OtpDigitTyped(0, '4'));
    expect(state.digits[0], '4');
    expect(state.focusIndex, 1);
    expect(state.notice, OtpNotice.none);
  });

  test('the sixth digit stays in the last box and completes the code', () {
    final state = typeCode('123456');
    expect(state.code, '123456');
    expect(state.focusIndex, 5);
    expect(state.isComplete, isTrue);
  });

  test('non-digits and empty input are rejected', () {
    final initial = OtpState.initial();
    expect(reduceOtp(initial, const OtpDigitTyped(0, 'a')), initial);
    expect(reduceOtp(initial, const OtpDigitTyped(0, '')), initial);
    expect(reduceOtp(initial, const OtpDigitTyped(0, '12')), initial);
    expect(reduceOtp(initial, const OtpDigitTyped(0, ' ')), initial);
    expect(reduceOtp(initial, const OtpDigitTyped(-1, '1')), initial);
  });

  test('a typed zero is a real digit, not the empty placeholder', () {
    final state = reduceOtp(OtpState.initial(), const OtpDigitTyped(0, '0'));
    expect(state.digits[0], '0');
    expect(state.focusIndex, 1);
  });

  test('backspace clears the current digit', () {
    final filled = reduceOtp(OtpState.initial(), const OtpDigitTyped(0, '8'));
    final cleared = reduceOtp(filled, const OtpBackspacePressed(0));
    expect(cleared.digits[0], isEmpty);
    expect(cleared.focusIndex, 0);
  });

  test('backspace on an empty box clears the previous digit', () {
    var state = reduceOtp(OtpState.initial(), const OtpDigitTyped(0, '2'));
    state = reduceOtp(state, const OtpDigitTyped(1, '1'));
    expect(state.focusIndex, 2);
    final next = reduceOtp(state, const OtpBackspacePressed(2));
    expect(next.digits, ['2', '', '', '', '', '']);
    expect(next.focusIndex, 1);
  });

  test('backspace on the empty first box does nothing', () {
    final initial = OtpState.initial();
    expect(reduceOtp(initial, const OtpBackspacePressed(0)), initial);
  });

  test('paste extracts 482913 from a sentence', () {
    final state = reduceOtp(
      OtpState.initial(),
      const OtpTextPasted(0, 'Your code is 482913'),
    );
    expect(state.code, '482913');
    expect(state.isComplete, isTrue);
    expect(state.focusIndex, 5);
  });

  test('paste with no digits does nothing', () {
    final initial = OtpState.initial();
    expect(
      reduceOtp(initial, const OtpTextPasted(0, 'no numbers here')),
      initial,
    );
  });

  test('overflow paste keeps the first six digits', () {
    final state = reduceOtp(
      OtpState.initial(),
      const OtpTextPasted(0, 'codes 9988776655 extra'),
    );
    expect(state.code, '998877');
    expect(state.focusIndex, 5);
  });

  test('paste starting mid-box drops digits that do not fit', () {
    var state = typeCode('12');
    state = reduceOtp(state, const OtpTextPasted(2, '999999'));
    expect(state.code, '129999');
    expect(state.focusIndex, 5);
  });

  test('submit is ignored until six digits are present', () {
    final partial = typeCode('12345');
    expect(reduceOtp(partial, const OtpSubmitPressed()), partial);
  });

  test('123456 submits successfully and keeps the code', () {
    final ready = typeCode('123456');
    final next = reduceOtp(ready, const OtpSubmitPressed());
    expect(next.notice, OtpNotice.success);
    expect(next.code, '123456');
    expect(noticeMessage(next.notice), kSuccessMessage);
  });

  test('a wrong code errors, clears every box, and focuses the first', () {
    final ready = typeCode('654321');
    final next = reduceOtp(ready, const OtpSubmitPressed());
    expect(next.notice, OtpNotice.error);
    expect(next.digits, List.filled(kOtpLength, ''));
    expect(next.focusIndex, 0);
    expect(noticeMessage(next.notice), kErrorMessage);
  });

  test('editing after an error clears the notice', () {
    final errored = reduceOtp(typeCode('000000'), const OtpSubmitPressed());
    final next = reduceOtp(errored, const OtpDigitTyped(0, '1'));
    expect(next.notice, OtpNotice.none);
    expect(next.digits[0], '1');
  });

  test('the countdown ticks from 30 to 0 and then stops', () {
    var state = OtpState.initial();
    expect(resendLabel(state.resendSeconds), 'Resend in 0:30');
    for (var i = 0; i < 21; i++) {
      state = reduceOtp(state, const OtpSecondElapsed());
    }
    expect(state.resendSeconds, 9);
    expect(resendLabel(state.resendSeconds), 'Resend in 0:09');
    for (var i = 0; i < 9; i++) {
      state = reduceOtp(state, const OtpSecondElapsed());
    }
    expect(state.resendSeconds, 0);
    expect(resendLabel(state.resendSeconds), kResendReady);
    expect(reduceOtp(state, const OtpSecondElapsed()), state);
  });

  test('resend is ignored during the countdown and restarts at zero', () {
    final counting = OtpState.initial();
    expect(reduceOtp(counting, const OtpResendPressed()), counting);
    var ready = counting;
    for (var i = 0; i < kCountdownSeconds; i++) {
      ready = reduceOtp(ready, const OtpSecondElapsed());
    }
    final restarted = reduceOtp(ready, const OtpResendPressed());
    expect(restarted.resendSeconds, kCountdownSeconds);
    expect(resendLabel(restarted.resendSeconds), 'Resend in 0:30');
    expect(restarted.digits, ready.digits);
  });

  test('labels name each digit position', () {
    expect(digitSemanticsLabel(0), 'Digit 1 of 6');
    expect(digitSemanticsLabel(5), 'Digit 6 of 6');
  });
}
