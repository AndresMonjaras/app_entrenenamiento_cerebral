import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/core/app_theme.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:pg_prep_mobile/features/minijuegos/switch_challenge_v2/switch_challenge_v2_screen.dart';
import 'package:pg_prep_mobile/features/training/switch_challenge.dart';

SwitchQuestion _question() => SwitchQuestion(
  input: [0, 1, 2, 3],
  firstRule: [1, 3, 4, 2],
  output: [3, 2, 1, 0],
  options: [
    [1, 3, 4, 2],
    [2, 3, 4, 1],
    [3, 2, 4, 1],
  ],
  correctIndex: 2,
);

Widget _app(Widget child, {bool reduced = false, double scale = 1}) =>
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );

Finder _option(int index) => find.descendant(
  of: find.byKey(ValueKey('switch-option-$index')),
  matching: find.byType(InkWell),
);

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 740);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Switch keeps both figure rows and two funnels visible in play', (
    tester,
  ) async {
    _phone(tester);
    final answers = <Object>[];
    await tester.pumpWidget(
      _app(
        MinijuegoSwitchChallenge(question: _question(), onSubmit: answers.add),
        scale: 2,
      ),
    );
    final input = find.byKey(const ValueKey('switch-input-sequence'));
    final target = find.byKey(const ValueKey('switch-static-target'));
    final inputPosition = tester.getRect(input);
    final targetPosition = tester.getRect(target);
    expect(find.byKey(const ValueKey('switch-upper-canopy')), findsOneWidget);
    expect(find.byKey(const ValueKey('switch-lower-canopy')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('switch-first-rule'))).dy,
      greaterThan(inputPosition.bottom),
    );
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('switch-input-$i')), findsOneWidget);
      expect(find.byKey(ValueKey('switch-target-$i')), findsOneWidget);
    }
    await tester.pump(const Duration(seconds: 30));
    expect(tester.getRect(input), inputPosition);
    expect(tester.getRect(target), targetPosition);
    expect(answers, isEmpty);
    expect(find.textContaining('EJEMPLO'), findsNothing);
    expect(find.textContaining('Correcta'), findsNothing);
    expect(find.byKey(const ValueKey('switch-demo-phase')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Switch only previews a touched option and submits once', (
    tester,
  ) async {
    _phone(tester);
    final answers = <Object>[];
    await tester.pumpWidget(
      _app(
        MinijuegoSwitchChallenge(question: _question(), onSubmit: answers.add),
      ),
    );
    final target = find.byKey(const ValueKey('switch-static-target'));
    final position = tester.getRect(target);
    final pressed = await tester.startGesture(tester.getCenter(_option(0)));
    await tester.pump(const Duration(milliseconds: 250));
    expect(answers, isEmpty);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.startsWith(
                  'Regla 1, 3, 4, 2. Resultado:',
                ) ??
                false),
      ),
      findsOneWidget,
    );
    expect(tester.getRect(target), position);
    await pressed.up();
    await tester.pump();
    expect(answers, [0]);
    await tester.tap(_option(1));
    await tester.pump();
    expect(answers, [0]);
    expect(find.textContaining('Coincide'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Switch example takes 24 seconds with stable input and target', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(const SwitchWalkthrough(), scale: 2));
    await tester.pump();
    final input = find.byKey(const ValueKey('switch-input-sequence'));
    final target = find.byKey(const ValueKey('switch-static-target'));
    final inputPosition = tester.getRect(input);
    final targetPosition = tester.getRect(target);
    for (final step in <(Duration, String)>[
      (const Duration(seconds: 3), '01 · Las figuras entran'),
      (const Duration(seconds: 2), '02 · 1342 produce'),
      (const Duration(seconds: 4), '03 · Prueba 1342'),
      (const Duration(seconds: 4), '03 · Prueba 2341'),
      (const Duration(seconds: 4), '04 · 3241 coincide'),
      (const Duration(seconds: 6), '04 · 3241 coincide'),
      (const Duration(seconds: 2), '01 · Las figuras entran'),
    ]) {
      await tester.pump(step.$1);
      expect(find.textContaining(step.$2), findsOneWidget);
      expect(tester.getRect(input), inputPosition);
      expect(tester.getRect(target), targetPosition);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('V2 shares the reference board and defers its result callback', (
    tester,
  ) async {
    _phone(tester);
    final attempts = <Attempt>[];
    final answers = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SwitchChallengeV2Screen(
          onResult: answers.add,
          onAttempt: attempts.add,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MinijuegoSwitchChallenge), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('opt_3')), findsOneWidget);
    await tester.tap(_option(0));
    await tester.pump();
    expect(attempts, hasLength(1));
    expect(attempts.single.skipped, isFalse);
    expect(answers, isEmpty);
    await tester.pump(const Duration(milliseconds: 499));
    expect(answers, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(answers, [attempts.single.correct]);
    expect(find.textContaining('Correcta'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('V2 cancels delayed callbacks when the round is removed', (
    tester,
  ) async {
    final attempts = <Attempt>[];
    final answers = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SwitchChallengeV2Screen(
          onResult: answers.add,
          onAttempt: attempts.add,
          showTimeBar: false,
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(_option(0));
    await tester.pump();
    expect(attempts, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(answers, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('V2 expires once and records an unanswered attempt', (
    tester,
  ) async {
    final attempts = <Attempt>[];
    final answers = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SwitchChallengeV2Screen(
          timerDuration: const Duration(seconds: 1),
          onResult: answers.add,
          onAttempt: attempts.add,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1001));
    expect(attempts, hasLength(1));
    expect(attempts.single.skipped, isTrue);
    expect(attempts.single.correct, isFalse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(answers, [false]);
    await tester.pump(const Duration(seconds: 5));
    expect(attempts, hasLength(1));
    expect(answers, [false]);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
