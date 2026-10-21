import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/core/app_theme.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:pg_prep_mobile/domain/round_controller.dart';
import 'package:pg_prep_mobile/features/training/mixed_sequence.dart';
import 'package:pg_prep_mobile/features/training/switch_challenge.dart'
    as switch_view;
import 'package:pg_prep_mobile/features/training/training_screen.dart';

Widget _app(Widget child, {double textScale = 1, bool reducedMotion = true}) =>
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
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

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tapAt(tester.getRect(target).center);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
}

Finder _cell(int cell) => find.byKey(ValueKey('recall-cell-$cell'));
Finder _marker(int cell) => find.byKey(ValueKey('recall-order-$cell'));

void _expectMarker(WidgetTester tester, int cell, int order) {
  expect(_marker(cell), findsOneWidget);
  expect(
    find.descendant(
      of: _marker(cell),
      matching: find.text('$order'),
      matchRoot: true,
    ),
    findsOneWidget,
  );
}

FilledButton _confirm(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Confirmar secuencia'),
);

void main() {
  setUpAll(() async {
    final fonts = FontLoader('FiraSans');
    for (final face in <String>['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/FiraSans-$face.otf'));
    }
    await fonts.load();
  });

  for (final type in [GameType.grid, GameType.symmetry]) {
    testWidgets(
      '${type.name} interleaves individual flashes and records ordered recall silently',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        var elapsed = Duration.zero;
        final controller = RoundController(
          type,
          const TrainingSettings(haptics: false),
          random: Random(7),
          elapsedNow: () => elapsed,
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
        });

        await tester.pumpWidget(
          _app(
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final question = controller.currentQuestion;
                return switch (question) {
                  PointFlashQuestion() => PointFlashView(
                    key: ValueKey(controller.questionNumber),
                    question: question,
                    controller: controller,
                  ),
                  MemorySequenceQuestion() => MemorySequenceRecall(
                    key: ValueKey(controller.questionNumber),
                    question: question,
                    onSubmit: controller.submit,
                    onSelectionChanged: controller.setRecallSelection,
                  ),
                  GridQuestion() => MinijuegoGridChallenge(
                    key: ValueKey(controller.questionNumber),
                    question: question,
                    onSubmit: controller.submit,
                  ),
                  _ => throw StateError('Unexpected mixed phase'),
                };
              },
            ),
          ),
        );
        await tester.pump();
        final sequence = controller.mixedSequence!;
        expect(sequence.sequence.length, 3);

        for (var index = 0; index < sequence.sequence.length; index++) {
          expect(controller.mixedPhase, MixedPhase.flash);
          expect(controller.currentQuestion, isA<PointFlashQuestion>());
          expect(controller.flashCell, sequence.sequence[index]);
          expect(find.byType(PointFlashView), findsOneWidget);
          expect(
            find.byKey(ValueKey('flash-target-${sequence.sequence[index]}')),
            findsOneWidget,
          );
          expect(find.text('Sí'), findsNothing);
          expect(find.text('No'), findsNothing);
          final stimulus = controller.questionNumber;
          controller.skip();
          controller.submit(true);
          expect(controller.questionNumber, stimulus);
          expect(() => controller.attempts, throwsStateError);
          elapsed += controller.flashDuration - const Duration(microseconds: 1);
          controller.refresh();
          await tester.pump();
          expect(controller.mixedPhase, MixedPhase.flash);
          elapsed += const Duration(microseconds: 1);
          controller.refresh();
          await tester.pump();
          expect(controller.mixedPhase, MixedPhase.reasoning);
          final reasoning = controller.currentQuestion as GridQuestion;
          expect(find.byType(MinijuegoGridChallenge), findsOneWidget);
          await _tap(tester, find.text(reasoning.correct ? 'Sí' : 'No'));
          expect(
            controller.mixedPhase,
            index == sequence.sequence.length - 1
                ? MixedPhase.recall
                : MixedPhase.flash,
          );
          expect(find.text('Correcta'), findsNothing);
          expect(find.text('Por mejorar'), findsNothing);
        }

        expect(controller.mixedPhase, MixedPhase.recall);
        expect(find.byType(MemorySequenceRecall), findsOneWidget);
        expect(_confirm(tester).onPressed, isNull);
        for (final cell in sequence.templateCells) {
          expect(_cell(cell), findsOneWidget);
        }
        final wrongOrder = sequence.sequence.reversed.toList();
        for (var index = 0; index < wrongOrder.length; index++) {
          await _tap(tester, _cell(wrongOrder[index]));
          _expectMarker(tester, wrongOrder[index], index + 1);
        }
        expect(_confirm(tester).onPressed, isNotNull);
        await _tap(tester, find.text('Confirmar secuencia'));
        expect(controller.mixedPhase, MixedPhase.flash);
        expect(() => controller.result, throwsStateError);
        controller.finish();
        final attempts = controller.result.attempts;
        expect(attempts, hasLength(sequence.sequence.length + 1));
        expect(
          attempts.take(sequence.sequence.length).every((a) => a.correct),
          isTrue,
        );
        expect(attempts.last.correct, isFalse);
        expect(attempts.last.skipped, isFalse);
        expect(attempts.last.given, sequence.answerLabel(wrongOrder));
        expect(attempts.last.expected, sequence.correctAnswerLabel);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.6, 2.0]) {
    testWidgets('ordered recall edits and controls fit 320px at $scale text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.reset);
      final question = MemorySequenceQuestion(
        templateCells: [0, 2, 7, 13, 21, 35],
        sequence: [7, 2, 13],
      );
      Object? submitted;
      var submissionCount = 0;
      await tester.pumpWidget(
        _app(
          MemorySequenceRecall(
            question: question,
            onSubmit: (value) {
              submitted = value;
              submissionCount++;
            },
          ),
          textScale: scale,
        ),
      );
      await tester.pump();
      expect(_confirm(tester).onPressed, isNull);
      expect(_cell(1), findsNothing);
      expect(submitted, isNull);
      expect(tester.takeException(), isNull);

      await _tap(tester, _cell(7));
      await _tap(tester, _cell(2));
      _expectMarker(tester, 7, 1);
      _expectMarker(tester, 2, 2);
      expect(_confirm(tester).onPressed, isNull);
      await _tap(tester, _cell(13));
      _expectMarker(tester, 13, 3);
      expect(_confirm(tester).onPressed, isNotNull);

      await _tap(tester, _cell(35));
      expect(_marker(35), findsNothing);
      await _tap(tester, find.text('Deshacer'));
      expect(_marker(13), findsNothing);
      expect(_confirm(tester).onPressed, isNull);
      await _tap(tester, _cell(7));
      expect(_marker(7), findsNothing);
      expect(_marker(2), findsNothing);
      await _tap(tester, _cell(35));
      _expectMarker(tester, 35, 1);
      await _tap(tester, find.text('Limpiar'));
      expect(_marker(35), findsNothing);
      expect(_confirm(tester).onPressed, isNull);

      for (final cell in question.sequence) {
        await _tap(tester, _cell(cell));
      }
      final confirmAgain = _confirm(tester).onPressed!;
      await _tap(tester, find.text('Confirmar secuencia'));
      // Ignore a callback queued before the first confirmation, so it cannot
      // answer the next stimulus a second time before the widget rebuilds.
      confirmAgain();
      await tester.pump();
      expect(submitted, orderedEquals(question.sequence));
      expect(submissionCount, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'ordered recall supports accessible point selection and editing',
    (tester) async {
      await tester.pumpWidget(
        _app(
          MemorySequenceRecall(
            question: MemorySequenceQuestion(
              templateCells: [0, 2, 7, 13, 21, 35],
              sequence: [7, 2],
            ),
            onSubmit: (_) {},
          ),
        ),
      );
      final first = find.semantics.byLabel('Punto en fila 2, columna 2');
      final second = find.semantics.byLabel('Punto en fila 1, columna 3');
      tester.semantics.tap(first);
      await tester.pump();
      _expectMarker(tester, 7, 1);
      tester.semantics.tap(second);
      await tester.pump();
      _expectMarker(tester, 2, 2);
      expect(_confirm(tester).onPressed, isNotNull);
      tester.semantics.tap(first);
      await tester.pump();
      expect(_marker(7), findsNothing);
      expect(_marker(2), findsNothing);
      expect(_confirm(tester).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Switch previews a held choice neutrally and submits only once', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.reset);
    final question = SwitchQuestion(
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
    final submitted = <Object>[];
    await tester.pumpWidget(
      _app(
        switch_view.MinijuegoSwitchChallenge(
          question: question,
          onSubmit: submitted.add,
        ),
        textScale: 2,
      ),
    );
    await tester.pump();
    final option = find.descendant(
      of: find.byKey(const ValueKey('switch-option-0')),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(option);
    final gesture = await tester.startGesture(tester.getCenter(option));
    await tester.pump(const Duration(milliseconds: 200));
    expect(submitted, isEmpty);
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
    expect(find.textContaining('Coincide'), findsNothing);
    expect(find.text('Correcta'), findsNothing);
    await gesture.up();
    await tester.pump();
    expect(submitted, [0]);
    await _tap(tester, option);
    expect(submitted, [0]);
    expect(find.byKey(const ValueKey('switch-options-arrow')), findsOneWidget);
    expect(find.byKey(const ValueKey('switch-static-target')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Switch tutorial tries the rules while its target remains static',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          const switch_view.SwitchWalkthrough(),
          textScale: 2,
          reducedMotion: false,
        ),
      );
      await tester.pump();
      final target = find.byKey(const ValueKey('switch-static-target'));
      await tester.ensureVisible(target);
      final position = tester.getRect(target);
      expect(find.textContaining('01 · Las figuras entran'), findsOneWidget);

      for (final step in <(Duration, String)>[
        (const Duration(milliseconds: 4500), '02 · 1342 produce'),
        (const Duration(milliseconds: 4000), '03 · Prueba 1342'),
        (const Duration(milliseconds: 4000), '03 · Prueba 2341'),
        (const Duration(milliseconds: 4500), '04 · 3241 coincide'),
      ]) {
        await tester.pump(step.$1);
        expect(find.textContaining(step.$2), findsOneWidget);
        expect(tester.getRect(target), position);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
