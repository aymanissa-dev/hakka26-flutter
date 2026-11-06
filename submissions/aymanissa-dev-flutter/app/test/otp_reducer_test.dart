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

  OtpState withSeconds(OtpState state, int seconds) {
    return OtpState(
      digits: state.digits,
      focusIndex: state.focusIndex,
      notice: state.notice,
      resendSeconds: seconds,
    );
  }

  OtpState elapse(OtpState state, int seconds) {
    for (var i = 0; i < seconds; i++) {
      state = reduceOtp(state, const OtpSecondElapsed());
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

  test('fullwidth and other non-ascii digits are rejected', () {
    final initial = OtpState.initial();
    const rejected = <String>[
      '\uFF15', // fullwidth 5
      '\uFF10', // fullwidth 0
      '\u0662', // arabic-indic 2
      '\u06F9', // extended arabic-indic 9
      '\u0966', // devanagari 0
      '\u00B2', // superscript 2
      '\u2460', // circled 1
    ];
    for (final digit in rejected) {
      expect(
        reduceOtp(initial, OtpDigitTyped(0, digit)),
        same(initial),
        reason: digit,
      );
    }

    expect(
      reduceOtp(
        initial,
        const OtpTextPasted(
          0,
          'Your code is \uFF14\uFF18\uFF12\uFF19\uFF11\uFF13',
        ),
      ),
      same(initial),
    );

    final mixed = reduceOtp(
      initial,
      const OtpTextPasted(0, 'code \uFF148\uFF12913 extra'),
    );
    expect(mixed.digits, ['8', '9', '1', '3', '', '']);
    expect(mixed.focusIndex, 4);
    expect(mixed.notice, OtpNotice.none);
    expect(mixed.resendSeconds, kCountdownSeconds);

    final embedded = reduceOtp(
      initial,
      const OtpTextPasted(
        0,
        '12'
        '\uFF13'
        '456',
      ),
    );
    expect(embedded.digits, ['1', '2', '4', '5', '6', '']);
    expect(embedded.focusIndex, 5);
    expect(embedded.isComplete, isFalse);
  });

  test('clearing a box disables submit until the code is complete again', () {
    final ready = withSeconds(typeCode('123456'), 19);
    final cleared = reduceOtp(ready, const OtpBackspacePressed(2));
    expect(cleared.digits, ['1', '2', '', '4', '5', '6']);
    expect(cleared.focusIndex, 2);
    expect(cleared.isComplete, isFalse);
    expect(cleared.notice, OtpNotice.none);
    expect(cleared.resendSeconds, 19);
    expect(reduceOtp(cleared, const OtpSubmitPressed()), same(cleared));

    final restored = reduceOtp(cleared, const OtpDigitTyped(2, '3'));
    expect(restored.code, '123456');
    expect(restored.isComplete, isTrue);
    expect(restored.focusIndex, 3);
    expect(restored.resendSeconds, 19);
    expect(
      reduceOtp(restored, const OtpSubmitPressed()).notice,
      OtpNotice.success,
    );
  });

  test('replacing a digit in a filled box overwrites only that box', () {
    final ready = elapse(typeCode('123456'), 6);
    expect(ready.resendSeconds, 24);
    final replaced = reduceOtp(ready, const OtpDigitTyped(2, '9'));
    expect(replaced.code, '129456');
    expect(replaced.focusIndex, 3);
    expect(replaced.isComplete, isTrue);
    expect(replaced.notice, OtpNotice.none);
    expect(replaced.resendSeconds, 24);

    final last = reduceOtp(replaced, const OtpDigitTyped(5, '0'));
    expect(last.code, '129450');
    expect(last.focusIndex, 5);
    expect(last.resendSeconds, 24);
    expect(reduceOtp(last, const OtpSubmitPressed()).notice, OtpNotice.error);
  });

  test('editing, focus, and backspace do not reset the countdown', () {
    var state = elapse(OtpState.initial(), 12);
    expect(state.resendSeconds, 18);

    state = reduceOtp(state, const OtpDigitTyped(0, '4'));
    expect(state.digits[0], '4');
    expect(state.focusIndex, 1);
    expect(state.resendSeconds, 18);

    state = reduceOtp(state, const OtpBoxFocused(0));
    expect(state.focusIndex, 0);
    expect(state.digits[0], '4');
    expect(state.resendSeconds, 18);

    state = reduceOtp(state, const OtpBackspacePressed(0));
    expect(state.digits[0], isEmpty);
    expect(state.focusIndex, 0);
    expect(state.resendSeconds, 18);

    state = reduceOtp(state, const OtpTextPasted(1, '99'));
    expect(state.digits, ['', '9', '9', '', '', '']);
    expect(state.focusIndex, 3);
    expect(state.notice, OtpNotice.none);
    expect(state.resendSeconds, 18);
  });

  test('submitting the success code again stays successful', () {
    final success = reduceOtp(
      withSeconds(typeCode(kSuccessCode), 17),
      const OtpSubmitPressed(),
    );
    final again = reduceOtp(success, const OtpSubmitPressed());
    expect(again.notice, OtpNotice.success);
    expect(again.code, kSuccessCode);
    expect(again.focusIndex, success.focusIndex);
    expect(again.resendSeconds, 17);
    expect(noticeMessage(again.notice), kSuccessMessage);
  });

  test('typing after success replaces the digit and clears the notice', () {
    final success = reduceOtp(
      withSeconds(typeCode(kSuccessCode), 17),
      const OtpSubmitPressed(),
    );
    expect(reduceOtp(success, const OtpDigitTyped(0, '\uFF15')), same(success));
    expect(
      reduceOtp(success, const OtpTextPasted(0, 'no digits')),
      same(success),
    );

    final replaced = reduceOtp(success, const OtpDigitTyped(2, '9'));
    expect(replaced.notice, OtpNotice.none);
    expect(replaced.code, '129456');
    expect(replaced.focusIndex, 3);
    expect(replaced.resendSeconds, 17);

    final retyped = reduceOtp(success, const OtpDigitTyped(5, '6'));
    expect(retyped.notice, OtpNotice.none);
    expect(retyped.code, kSuccessCode);
    expect(retyped.focusIndex, 5);
    expect(retyped.resendSeconds, 17);
  });

  test('backspace after success clears the digit and the notice', () {
    final success = reduceOtp(
      withSeconds(typeCode(kSuccessCode), 17),
      const OtpSubmitPressed(),
    );
    final cleared = reduceOtp(success, const OtpBackspacePressed(5));
    expect(cleared.notice, OtpNotice.none);
    expect(cleared.code, '12345');
    expect(cleared.focusIndex, 5);
    expect(cleared.isComplete, isFalse);
    expect(cleared.resendSeconds, 17);
    expect(reduceOtp(cleared, const OtpSubmitPressed()), same(cleared));
  });

  test('resend after success keeps the code and the notice', () {
    var success = reduceOtp(
      withSeconds(typeCode(kSuccessCode), 4),
      const OtpSubmitPressed(),
    );
    expect(reduceOtp(success, const OtpResendPressed()), same(success));

    success = elapse(success, 4);
    expect(success.resendSeconds, 0);
    expect(success.notice, OtpNotice.success);
    expect(success.code, kSuccessCode);

    final restarted = reduceOtp(success, const OtpResendPressed());
    expect(restarted.resendSeconds, kCountdownSeconds);
    expect(restarted.notice, OtpNotice.success);
    expect(restarted.code, kSuccessCode);
    expect(restarted.focusIndex, success.focusIndex);
  });

  test('paste after an error fills the code and clears the notice', () {
    final errored = reduceOtp(
      withSeconds(typeCode('999999'), 16),
      const OtpSubmitPressed(),
    );
    expect(errored.notice, OtpNotice.error);
    final pasted = reduceOtp(
      errored,
      const OtpTextPasted(0, 'Your code is 482913'),
    );
    expect(pasted.code, '482913');
    expect(pasted.isComplete, isTrue);
    expect(pasted.focusIndex, 5);
    expect(pasted.notice, OtpNotice.none);
    expect(pasted.resendSeconds, 16);
  });

  test('submit after an error waits until the code is complete', () {
    final errored = reduceOtp(
      withSeconds(typeCode('654321'), 11),
      const OtpSubmitPressed(),
    );
    expect(reduceOtp(errored, const OtpSubmitPressed()), same(errored));

    var partial = errored;
    for (var i = 0; i < 5; i++) {
      partial = reduceOtp(partial, OtpDigitTyped(i, '9'));
    }
    expect(partial.notice, OtpNotice.none);
    expect(partial.code, '99999');
    expect(partial.isComplete, isFalse);
    expect(partial.resendSeconds, 11);
    expect(reduceOtp(partial, const OtpSubmitPressed()), same(partial));

    final wrong = reduceOtp(partial, const OtpDigitTyped(5, '9'));
    final rejected = reduceOtp(wrong, const OtpSubmitPressed());
    expect(rejected.notice, OtpNotice.error);
    expect(rejected.digits, List.filled(kOtpLength, ''));
    expect(rejected.focusIndex, 0);
    expect(rejected.resendSeconds, 11);

    var retry = rejected;
    for (var i = 0; i < kSuccessCode.length; i++) {
      retry = reduceOtp(retry, OtpDigitTyped(i, kSuccessCode[i]));
    }
    final accepted = reduceOtp(retry, const OtpSubmitPressed());
    expect(accepted.notice, OtpNotice.success);
    expect(accepted.code, kSuccessCode);
    expect(accepted.resendSeconds, 11);
  });

  test('a tick during success or error only changes the countdown', () {
    final success = reduceOtp(
      withSeconds(typeCode(kSuccessCode), 8),
      const OtpSubmitPressed(),
    );
    final tickedSuccess = reduceOtp(success, const OtpSecondElapsed());
    expect(tickedSuccess.resendSeconds, 7);
    expect(tickedSuccess.notice, OtpNotice.success);
    expect(tickedSuccess.code, kSuccessCode);
    expect(tickedSuccess.focusIndex, success.focusIndex);

    final errored = reduceOtp(
      withSeconds(typeCode('000000'), 3),
      const OtpSubmitPressed(),
    );
    final tickedError = reduceOtp(errored, const OtpSecondElapsed());
    expect(tickedError.resendSeconds, 2);
    expect(tickedError.notice, OtpNotice.error);
    expect(tickedError.digits, List.filled(kOtpLength, ''));
    expect(tickedError.focusIndex, 0);

    final stoppedSuccess = withSeconds(success, 0);
    expect(
      reduceOtp(stoppedSuccess, const OtpSecondElapsed()),
      same(stoppedSuccess),
    );
    final stoppedError = withSeconds(errored, 0);
    expect(
      reduceOtp(stoppedError, const OtpSecondElapsed()),
      same(stoppedError),
    );
  });

  test('resend at zero keeps entered digits, focus, and notice', () {
    final ready = elapse(typeCode('12'), kCountdownSeconds);
    expect(ready.resendSeconds, 0);
    expect(ready.code, '12');
    expect(ready.focusIndex, 2);
    final restarted = reduceOtp(ready, const OtpResendPressed());
    expect(restarted.resendSeconds, kCountdownSeconds);
    expect(restarted.code, '12');
    expect(restarted.focusIndex, 2);
    expect(restarted.notice, OtpNotice.none);

    final errored = elapse(
      reduceOtp(typeCode('000000'), const OtpSubmitPressed()),
      kCountdownSeconds,
    );
    final resent = reduceOtp(errored, const OtpResendPressed());
    expect(resent.notice, OtpNotice.error);
    expect(resent.digits, List.filled(kOtpLength, ''));
    expect(resent.focusIndex, 0);
    expect(resent.resendSeconds, kCountdownSeconds);
  });

  test('focus ignores an out-of-range index and leaves the notice alone', () {
    final initial = OtpState.initial();
    expect(reduceOtp(initial, const OtpBoxFocused(-1)), same(initial));
    expect(reduceOtp(initial, const OtpBoxFocused(6)), same(initial));
    expect(reduceOtp(initial, const OtpBoxFocused(0)), same(initial));

    final errored = reduceOtp(
      withSeconds(typeCode('111111'), 16),
      const OtpSubmitPressed(),
    );
    expect(reduceOtp(errored, const OtpBoxFocused(-1)), same(errored));
    expect(reduceOtp(errored, const OtpBoxFocused(6)), same(errored));
    final moved = reduceOtp(errored, const OtpBoxFocused(4));
    expect(moved.focusIndex, 4);
    expect(moved.notice, OtpNotice.error);
    expect(moved.digits, List.filled(kOtpLength, ''));
    expect(moved.resendSeconds, 16);
    expect(reduceOtp(moved, const OtpBoxFocused(4)), same(moved));

    final success = reduceOtp(
      withSeconds(typeCode(kSuccessCode), 16),
      const OtpSubmitPressed(),
    );
    final refocused = reduceOtp(success, const OtpBoxFocused(1));
    expect(refocused.notice, OtpNotice.success);
    expect(refocused.code, kSuccessCode);
    expect(refocused.focusIndex, 1);
    expect(refocused.resendSeconds, 16);
  });

  test('other wrong codes clear the boxes and keep the countdown', () {
    const wrongCodes = <String>[
      '000000',
      '111111',
      '123455',
      '123457',
      '012345',
      '999999',
      '100000',
    ];
    for (final code in wrongCodes) {
      final ready = withSeconds(typeCode(code), 14);
      final next = reduceOtp(ready, const OtpSubmitPressed());
      expect(next.notice, OtpNotice.error, reason: code);
      expect(next.digits, List.filled(kOtpLength, ''), reason: code);
      expect(next.focusIndex, 0, reason: code);
      expect(next.resendSeconds, 14, reason: code);
      expect(noticeMessage(next.notice), kErrorMessage, reason: code);
      expect(
        reduceOtp(next, const OtpSubmitPressed()),
        same(next),
        reason: code,
      );
    }
  });

  test('typing, backspace, and paste ignore an out-of-range box', () {
    final filled = typeCode('12');
    expect(reduceOtp(filled, const OtpDigitTyped(6, '3')), same(filled));
    expect(reduceOtp(filled, const OtpBackspacePressed(6)), same(filled));
    expect(reduceOtp(filled, const OtpBackspacePressed(-1)), same(filled));
    expect(reduceOtp(filled, const OtpTextPasted(6, '482913')), same(filled));
    expect(reduceOtp(filled, const OtpTextPasted(-1, '482913')), same(filled));
  });

  test('backspace after an error keeps the error until focus moves back', () {
    final errored = reduceOtp(
      withSeconds(typeCode('222222'), 21),
      const OtpSubmitPressed(),
    );
    expect(reduceOtp(errored, const OtpBackspacePressed(0)), same(errored));

    final shifted = reduceOtp(errored, const OtpBackspacePressed(3));
    expect(shifted.notice, OtpNotice.none);
    expect(shifted.focusIndex, 2);
    expect(shifted.digits, List.filled(kOtpLength, ''));
    expect(shifted.resendSeconds, 21);
  });
}
