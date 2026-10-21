import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:pg_prep_mobile/domain/round_controller.dart';
import 'package:pg_prep_mobile/domain/stroke_equation.dart';

LineStroke line(int x, int y, int a, int b) =>
    LineStroke((x: x, y: y), (x: a, y: b));
void main() {
  test(
    'the reference H is accepted and an extra central trace is rejected',
    () {
      final good = StrokeEquationGenerator.example();
      final bad = StrokeEquationGenerator.example(correct: false);
      expect(good.check(true), isTrue);
      expect(good.check(false), isFalse);
      expect(bad.check(false), isTrue);
      expect(bad.check(true), isFalse);
      expect(good.check('Sí'), isFalse);
      expect(good.correctAnswerLabel, 'Sí');
      expect(bad.answerLabel(false), 'No');
    },
  );
  test('line direction, duplicates, overlap and collinear subdivisions do not change the drawing', () {
    final whole = [line(0, 0, 72, 0), line(36, 0, 36, 72)];
    final fragments = [
      line(72, 0, 36, 0),
      line(0, 0, 48, 0),
      line(36, 72, 36, 24),
      line(36, 0, 36, 36),
      line(0, 0, 48, 0),
    ];
    expect(sameStrokeGeometry(whole, fragments), isTrue);
    expect(sameStrokeGeometry(fragments, whole), isTrue);
    expect(line(72, 0, 0, 0), line(0, 0, 72, 0));
    expect({line(72, 0, 0, 0), line(0, 0, 72, 0)}, hasLength(1));
    expect(
      sameStrokeGeometry(
        [line(0, 0, 72, 72)],
        [line(0, 0, 36, 36), line(72, 72, 36, 36)],
      ),
      isTrue,
    );
  });
  test('a tiny gap, shift, deformation or extra line fails even when endpoints look similar', () {
    final whole = [line(0, 0, 72, 0), line(0, 0, 72, 72)];
    for (final incorrect in [
      [line(0, 0, 35, 0), line(36, 0, 72, 0), line(0, 0, 72, 72)],
      [line(0, 1, 72, 1), line(0, 0, 72, 72)],
      [line(0, 0, 72, 1), line(0, 0, 72, 72)],
      [...whole, line(0, 72, 72, 0)],
      [line(0, 0, 72, 0)],
    ]) {
      expect(sameStrokeGeometry(whole, incorrect), isFalse);
    }
  });
  test('every mutation produces a false equation at both complexities, with no invalid positions', () {
    for (final difficulty in Difficulty.values) {
      final generator = StrokeEquationGenerator(random: Random(410));
      for (final alteration in StrokeAlteration.values) {
        for (var i = 1; i <= 60; i++) {
          final q = generator.generate(
            difficulty,
            questionNumber: i,
            alteration: alteration,
          );
          expect(q.correct, alteration == StrokeAlteration.none);
          expect(
            q.left.length,
            greaterThanOrEqualTo(difficulty == Difficulty.expert ? 25 : 18),
          );
          expect(q.left.toSet().intersection(q.right.toSet()), hasLength(4));
          for (final stroke in [...q.left, ...q.right, ...q.result]) {
            expect(stroke.start, isNot(stroke.end));
            for (final point in [stroke.start, stroke.end]) {
              expect(point.x, inInclusiveRange(0, 72));
              expect(point.y, inInclusiveRange(0, 72));
            }
          }
        }
      }
    }
  });
  test(
    'questions keep immutable inputs and reject empty or zero-length shapes',
    () {
      final input = [line(0, 0, 72, 0)];
      final q = StrokeEquationQuestion(
        left: input,
        right: input,
        result: input,
      );
      input.clear();
      expect(q.left, hasLength(1));
      expect(() => q.result.clear(), throwsUnsupportedError);
      expect(() => line(1, 1, 1, 1), throwsArgumentError);
      expect(() => line(-1, 0, 72, 0), throwsArgumentError);
      expect(
        () =>
            StrokeEquationQuestion(left: [], right: q.right, result: q.result),
        throwsArgumentError,
      );
    },
  );
  test('Grid and symmetry mixed rounds have a fixed three-minute limit', () {
    for (final configured in [5, 6]) {
      final settings = TrainingSettings(roundMinutes: configured);
      for (final game in GameType.values) {
        var elapsed = Duration.zero;
        final controller = RoundController(
          game,
          settings,
          elapsedNow: () => elapsed,
          mixedSequences: false,
        );
        final duration = Duration(
          minutes:
              game == GameType.memory ||
                  game == GameType.grid ||
                  game == GameType.symmetry ||
                  game == GameType.mixed
              ? 3
              : configured,
        );
        expect(controller.duration, duration);
        expect(controller.remaining.value, duration);
        elapsed = duration - const Duration(microseconds: 1);
        controller.refresh();
        expect(controller.isFinished, isFalse);
        elapsed = duration;
        controller.refresh();
        expect(controller.isFinished, isTrue);
        expect(controller.result.duration, duration);
        controller.dispose();
      }
      expect(
        settings.simulationDuration,
        Duration(minutes: 6 + configured * 3),
      );
    }
  });
  test(
    'stroke answers advance silently and the final report records both choices',
    () {
      final controller = RoundController(
        GameType.strokes,
        const TrainingSettings(),
        random: Random(12),
      );
      final first = controller.currentQuestion as StrokeEquationQuestion;
      controller.submit(!first.correct);
      final next = controller.currentQuestion as StrokeEquationQuestion;
      expect(next, isNot(same(first)));
      expect(() => controller.attempts, throwsStateError);
      controller.submit(next.correct);
      controller.finish();
      expect(controller.result.attempts.map((a) => a.correct), [false, true]);
      expect(
        controller.result.attempts.first.expected,
        first.correctAnswerLabel,
      );
      controller.dispose();
    },
  );
}
