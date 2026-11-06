import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hakka/main.dart';
import 'package:hakka/otp/otp_colors.dart';
import 'package:hakka/otp/otp_reducer.dart';

void main() {
  setUp(() {
    // Asset futures are cached on the root bundle. A future completed in one
    // test's fake-async zone does not resume in the next test.
    rootBundle.evict('assets/colours.json');
    rootBundle.evict('assets/thamani-logo.png');
    rootBundle.evict('assets/thamani-logo-white.png');
  });

  Future<void> pumpOtp(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const HakkaApp());
    await tester.pump();
    await tester.pump();
    expect(find.text(kTitle), findsOneWidget);
  }

  Finder box(int oneBased) => find.byKey(Key('otp_digit_$oneBased'));

  Future<void> enter(WidgetTester tester, int oneBased, String text) async {
    await tester.enterText(box(oneBased), text);
    // The field commits on the next frame, then the sheet rebuilds.
    await tester.pump();
    await tester.pump();
  }

  String boxText(WidgetTester tester, int oneBased) {
    return tester
        .widget<EditableText>(
          find.descendant(
            of: box(oneBased),
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text;
  }

  bool boxFocused(WidgetTester tester, int oneBased) {
    return tester
        .widget<EditableText>(
          find.descendant(
            of: box(oneBased),
            matching: find.byType(EditableText),
          ),
        )
        .focusNode
        .hasFocus;
  }

  BoxDecoration boxDecoration(WidgetTester tester, int oneBased) {
    return tester.widget<Container>(box(oneBased)).decoration! as BoxDecoration;
  }

  TextField boxField(WidgetTester tester, int oneBased) {
    return tester.widget<TextField>(
      find.descendant(of: box(oneBased), matching: find.byType(TextField)),
    );
  }

  FilledButton submitButton(WidgetTester tester) {
    return tester.widget<FilledButton>(find.byKey(const Key('otp_submit')));
  }

  String enteredCode(WidgetTester tester) {
    return [for (var i = 1; i <= 6; i++) boxText(tester, i)].join();
  }

  Future<void> pressBackspace(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the copy, six boxes, and a disabled submit button', (
    tester,
  ) async {
    await pumpOtp(tester);
    expect(find.text(kSubtitle), findsOneWidget);
    expect(find.text(kSubmitLabel), findsOneWidget);
    expect(find.text('Resend in 0:30'), findsOneWidget);
    expect(find.text(kSuccessMessage), findsNothing);
    expect(find.text(kErrorMessage), findsNothing);
    for (var i = 1; i <= 6; i++) {
      expect(box(i), findsOneWidget);
    }
    final first = boxField(tester, 1);
    expect(first.keyboardType, TextInputType.number);
    expect(first.autofocus, isTrue);
    expect(boxFocused(tester, 1), isTrue);
    expect(boxField(tester, 1).decoration?.hintText, isNull);
    expect(boxField(tester, 6).decoration?.hintText, kPlaceholder);
    expect(boxField(tester, 6).decoration?.hintText, isNot('0'));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('otp_submit')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('announces Digit N of 6 and the test ids', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOtp(tester);
    for (var i = 1; i <= 6; i++) {
      expect(find.bySemanticsLabel('Digit $i of 6'), findsOneWidget);
      expect(find.bySemanticsIdentifier('otp_digit_$i'), findsOneWidget);
    }
    expect(find.bySemanticsIdentifier('otp_submit'), findsOneWidget);
    expect(find.bySemanticsIdentifier('otp_resend'), findsOneWidget);
    expect(find.bySemanticsIdentifier('otp_status'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('typing advances, fills from the palette, and enables submit', (
    tester,
  ) async {
    await pumpOtp(tester);
    final palettes = await OtpPalettes.load();
    await enter(tester, 1, '2');
    await enter(tester, 2, '1');
    expect(boxText(tester, 1), '2');
    expect(boxText(tester, 2), '1');
    expect(boxFocused(tester, 3), isTrue);
    expect(boxDecoration(tester, 1).color, palettes.light.digitFilledBg);
    expect(boxDecoration(tester, 3).color, palettes.light.digitFocusedBg);
    expect(boxDecoration(tester, 6).color, palettes.light.digitEmptyBg);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('otp_submit')))
          .onPressed,
      isNull,
    );
    await enter(tester, 3, '3');
    await enter(tester, 4, '4');
    await enter(tester, 5, '5');
    await enter(tester, 6, '6');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('otp_submit')))
          .onPressed,
      isNotNull,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('otp_submit')),
    );
    expect(button.style?.backgroundColor?.resolve({}), palettes.light.buttonBg);
  });

  testWidgets('a typed zero uses the filled colour, not the placeholder', (
    tester,
  ) async {
    await pumpOtp(tester);
    final palettes = await OtpPalettes.load();
    await enter(tester, 1, '0');
    expect(boxText(tester, 1), '0');
    expect(boxDecoration(tester, 1).color, palettes.light.digitFilledBg);
    expect(boxDecoration(tester, 1).color, isNot(palettes.light.digitEmptyBg));
  });

  testWidgets('non-digits are rejected', (tester) async {
    await pumpOtp(tester);
    await enter(tester, 1, 'a');
    expect(boxText(tester, 1), isEmpty);
    expect(boxFocused(tester, 1), isTrue);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('otp_submit')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('pasting a sentence fills 482913', (tester) async {
    await pumpOtp(tester);
    await enter(tester, 1, 'Your code is 482913');
    expect([for (var i = 1; i <= 6; i++) boxText(tester, i)].join(), '482913');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('otp_submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('overflow paste keeps the first six digits', (tester) async {
    await pumpOtp(tester);
    await enter(tester, 1, 'codes 9988776655 extra');
    expect([for (var i = 1; i <= 6; i++) boxText(tester, i)].join(), '998877');
  });

  testWidgets('backspace on the empty first box does nothing', (tester) async {
    await pumpOtp(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(boxText(tester, 1), isEmpty);
    expect(boxFocused(tester, 1), isTrue);
    expect(find.text(kErrorMessage), findsNothing);
  });

  testWidgets('backspace on an empty box clears the previous digit', (
    tester,
  ) async {
    await pumpOtp(tester);
    await enter(tester, 1, '2');
    await enter(tester, 2, '1');
    expect(boxFocused(tester, 3), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(boxText(tester, 1), '2');
    expect(boxText(tester, 2), isEmpty);
    expect(boxFocused(tester, 2), isTrue);
  });

  testWidgets('tapping submit while incomplete does nothing', (tester) async {
    await pumpOtp(tester);
    await enter(tester, 1, '1');
    await tester.tap(find.byKey(const Key('otp_submit')));
    await tester.pump();
    expect(find.text(kSuccessMessage), findsNothing);
    expect(find.text(kErrorMessage), findsNothing);
    expect(boxText(tester, 1), '1');
  });

  testWidgets('123456 shows the success message and keeps the code', (
    tester,
  ) async {
    await pumpOtp(tester);
    await enter(tester, 1, '123456');
    await tester.tap(find.byKey(const Key('otp_submit')));
    await tester.pump();
    expect(find.text(kSuccessMessage), findsOneWidget);
    expect(find.text(kErrorMessage), findsNothing);
    expect([for (var i = 1; i <= 6; i++) boxText(tester, i)].join(), '123456');
  });

  testWidgets(
    'a wrong code shows the error, clears, and focuses the first box',
    (tester) async {
      await pumpOtp(tester);
      await enter(tester, 1, '654321');
      await tester.tap(find.byKey(const Key('otp_submit')));
      await tester.pump();
      expect(find.text(kErrorMessage), findsOneWidget);
      expect(find.text(kSuccessMessage), findsNothing);
      for (var i = 1; i <= 6; i++) {
        expect(boxText(tester, i), isEmpty);
      }
      expect(boxFocused(tester, 1), isTrue);
      await enter(tester, 1, '9');
      expect(find.text(kErrorMessage), findsNothing);
      expect(boxText(tester, 1), '9');
    },
  );

  testWidgets('resend counts down, then restarts when tapped', (tester) async {
    await pumpOtp(tester);
    expect(find.text('Resend in 0:30'), findsOneWidget);
    await tester.tap(find.byKey(const Key('otp_resend')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resend in 0:29'), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Resend in 0:09'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    expect(find.text(kResendReady), findsOneWidget);

    await tester.tap(find.byKey(const Key('otp_resend')));
    await tester.pump();
    expect(find.text('Resend in 0:30'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resend in 0:29'), findsOneWidget);
  });

  testWidgets('dark mode uses the dark palette and white logo', (tester) async {
    await pumpOtp(tester, brightness: Brightness.dark);
    final palettes = await OtpPalettes.load();
    final sheet = tester.widget<Container>(find.byKey(const Key('otp_sheet')));
    expect((sheet.decoration as BoxDecoration).color, palettes.dark.sheet);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      dimmedPage(palettes.dark),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/thamani-logo-white.png',
    );
    await enter(tester, 1, '4');
    expect(boxDecoration(tester, 1).color, palettes.dark.digitFilledBg);
    expect(boxDecoration(tester, 2).color, palettes.dark.digitFocusedBg);
    expect(find.text(kTitle), findsOneWidget);
  });

  testWidgets('light mode sheet and disabled button use the light palette', (
    tester,
  ) async {
    await pumpOtp(tester);
    final palettes = await OtpPalettes.load();
    final sheet = tester.widget<Container>(find.byKey(const Key('otp_sheet')));
    expect((sheet.decoration as BoxDecoration).color, palettes.light.sheet);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('otp_submit')),
    );
    expect(
      button.style?.backgroundColor?.resolve({WidgetState.disabled}),
      palettes.light.buttonDisabledBg,
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/thamani-logo.png');
  });

  testWidgets('clearing a box disables submit again', (tester) async {
    await pumpOtp(tester);
    await enter(tester, 1, '123456');
    expect(submitButton(tester).onPressed, isNotNull);

    await enter(tester, 3, '');
    expect(enteredCode(tester), '12456');
    expect(boxText(tester, 3), isEmpty);
    expect(boxFocused(tester, 3), isTrue);
    expect(submitButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const Key('otp_submit')));
    await tester.pump();
    expect(find.text(kSuccessMessage), findsNothing);
    expect(find.text(kErrorMessage), findsNothing);
    expect(enteredCode(tester), '12456');
  });

  testWidgets('replacing a digit in a filled box keeps the other digits', (
    tester,
  ) async {
    await pumpOtp(tester);
    await enter(tester, 1, '123456');
    await enter(tester, 3, '9');
    expect(enteredCode(tester), '129456');
    expect(boxFocused(tester, 4), isTrue);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('typing, focus, and backspace do not reset the countdown', (
    tester,
  ) async {
    await pumpOtp(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Resend in 0:25'), findsOneWidget);

    await enter(tester, 1, '4');
    expect(boxText(tester, 1), '4');
    expect(find.text('Resend in 0:25'), findsOneWidget);

    await tester.tap(find.byKey(const Key('otp_resend')));
    await tester.pump();
    expect(boxText(tester, 1), '4');
    expect(find.text('Resend in 0:25'), findsOneWidget);

    await tester.tap(box(1));
    await tester.pump();
    expect(boxFocused(tester, 1), isTrue);
    expect(find.text('Resend in 0:25'), findsOneWidget);

    await pressBackspace(tester);
    expect(boxText(tester, 1), isEmpty);
    expect(boxFocused(tester, 1), isTrue);
    expect(find.text('Resend in 0:25'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resend in 0:24'), findsOneWidget);
  });

  testWidgets(
    'submitting again after success keeps the code while time ticks',
    (tester) async {
      await pumpOtp(tester);
      final palettes = await OtpPalettes.load();
      await enter(tester, 1, '123456');
      await tester.tap(find.byKey(const Key('otp_submit')));
      await tester.pump();
      expect(find.text(kSuccessMessage), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(kSuccessMessage)).style?.color,
        palettes.light.success,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(kSuccessMessage), findsOneWidget);
      expect(find.text(kErrorMessage), findsNothing);
      expect(enteredCode(tester), '123456');
      expect(find.text('Resend in 0:29'), findsOneWidget);

      await tester.tap(find.byKey(const Key('otp_submit')));
      await tester.pump();
      expect(find.text(kSuccessMessage), findsOneWidget);
      expect(enteredCode(tester), '123456');
      expect(find.text('Resend in 0:29'), findsOneWidget);
    },
  );

  testWidgets(
    'typing after success clears the message and replaces the digit',
    (tester) async {
      await pumpOtp(tester);
      await enter(tester, 1, '123456');
      await tester.tap(find.byKey(const Key('otp_submit')));
      await tester.pump();
      expect(find.text(kSuccessMessage), findsOneWidget);

      await enter(tester, 6, '7');
      expect(find.text(kSuccessMessage), findsNothing);
      expect(enteredCode(tester), '123457');
      expect(submitButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('otp_submit')));
      await tester.pump();
      expect(find.text(kErrorMessage), findsOneWidget);
      expect(enteredCode(tester), isEmpty);
    },
  );

  testWidgets('backspace after success clears the focused digit and message', (
    tester,
  ) async {
    await pumpOtp(tester);
    await enter(tester, 1, '123456');
    await tester.tap(find.byKey(const Key('otp_submit')));
    await tester.pump();
    expect(find.text(kSuccessMessage), findsOneWidget);

    await tester.tap(box(6));
    await tester.pump();
    expect(boxFocused(tester, 6), isTrue);
    expect(find.text(kSuccessMessage), findsOneWidget);

    await pressBackspace(tester);
    expect(find.text(kSuccessMessage), findsNothing);
    expect(enteredCode(tester), '12345');
    expect(boxText(tester, 6), isEmpty);
    expect(boxFocused(tester, 6), isTrue);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets(
    'resend after success restarts the countdown and keeps the code',
    (tester) async {
      await pumpOtp(tester);
      await enter(tester, 1, '123456');
      await tester.tap(find.byKey(const Key('otp_submit')));
      await tester.pump();
      expect(find.text(kSuccessMessage), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text(kSuccessMessage), findsOneWidget);
      expect(enteredCode(tester), '123456');
      expect(find.text(kResendReady), findsOneWidget);

      await tester.tap(find.byKey(const Key('otp_resend')));
      await tester.pump();
      expect(find.text('Resend in 0:30'), findsOneWidget);
      expect(find.text(kSuccessMessage), findsOneWidget);
      expect(enteredCode(tester), '123456');
    },
  );

  testWidgets('pasting after an error clears the message and fills the code', (
    tester,
  ) async {
    await pumpOtp(tester);
    await enter(tester, 1, '999999');
    await tester.tap(find.byKey(const Key('otp_submit')));
    await tester.pump();
    expect(find.text(kErrorMessage), findsOneWidget);

    await enter(tester, 1, 'Your code is 482913');
    expect(find.text(kErrorMessage), findsNothing);
    expect(find.text(kSuccessMessage), findsNothing);
    expect(enteredCode(tester), '482913');
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets(
    'submit stays disabled after an error until six digits are entered',
    (tester) async {
      await pumpOtp(tester);
      final palettes = await OtpPalettes.load();
      await enter(tester, 1, '000000');
      await tester.tap(find.byKey(const Key('otp_submit')));
      await tester.pump();
      expect(find.text(kErrorMessage), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(kErrorMessage)).style?.color,
        palettes.light.error,
      );
      expect(enteredCode(tester), isEmpty);
      expect(submitButton(tester).onPressed, isNull);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(kErrorMessage), findsOneWidget);
      expect(enteredCode(tester), isEmpty);
      expect(find.text('Resend in 0:29'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const Key('otp_submit')));
      await tester.pump();
      expect(find.text(kErrorMessage), findsOneWidget);
      expect(enteredCode(tester), isEmpty);

      await enter(tester, 1, '11111');
      expect(find.text(kErrorMessage), findsNothing);
      expect(enteredCode(tester), '11111');
      expect(submitButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const Key('otp_submit')));
      await tester.pump();
      expect(find.text(kErrorMessage), findsNothing);
      expect(enteredCode(tester), '11111');

      await enter(tester, 6, '1');
      expect(enteredCode(tester), '111111');
      expect(submitButton(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('otp_submit')));
      await tester.pump();
      expect(find.text(kErrorMessage), findsOneWidget);
      expect(enteredCode(tester), isEmpty);
      expect(boxFocused(tester, 1), isTrue);
    },
  );

  testWidgets('resend at zero keeps the digits already entered', (
    tester,
  ) async {
    await pumpOtp(tester);
    await enter(tester, 1, '12');
    expect(boxFocused(tester, 3), isTrue);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text(kResendReady), findsOneWidget);
    expect(boxText(tester, 1), '1');
    expect(boxText(tester, 2), '2');

    await tester.tap(find.byKey(const Key('otp_resend')));
    await tester.pump();
    expect(find.text('Resend in 0:30'), findsOneWidget);
    expect(boxText(tester, 1), '1');
    expect(boxText(tester, 2), '2');
    expect(boxFocused(tester, 3), isTrue);
  });

  testWidgets('pasting into a later box fills only the remaining boxes', (
    tester,
  ) async {
    await pumpOtp(tester);
    await enter(tester, 1, '12');
    await enter(tester, 3, 'Your code is 482913');
    expect(enteredCode(tester), '124829');
    expect(boxFocused(tester, 6), isTrue);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('fullwidth and mixed unicode digits are left out of the boxes', (
    tester,
  ) async {
    await pumpOtp(tester);
    await enter(tester, 1, '\uFF15');
    expect(boxText(tester, 1), isEmpty);
    expect(boxFocused(tester, 1), isTrue);

    await enter(tester, 1, '\u0661\u0662\u0663');
    expect(boxText(tester, 1), isEmpty);
    expect(enteredCode(tester), isEmpty);

    await enter(tester, 1, 'code \uFF148\uFF12913 extra');
    expect(enteredCode(tester), '8913');
    expect(boxFocused(tester, 5), isTrue);
    expect(submitButton(tester).onPressed, isNull);
  });
}
