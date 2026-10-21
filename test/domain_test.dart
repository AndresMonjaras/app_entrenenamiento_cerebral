import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:pg_prep_mobile/domain/stroke_equation.dart';
import 'package:pg_prep_mobile/domain/question_generator.dart';
import 'package:pg_prep_mobile/domain/round_controller.dart';

void main() {
  test('memory-interleaved Grid and symmetry rounds use three minutes', () {
    for (final minutes in [5, 6]) {
      final settings = TrainingSettings(roundMinutes: minutes);
      for (final type in [
        GameType.memory,
        GameType.grid,
        GameType.symmetry,
        GameType.mixed,
      ]) {
        expect(settings.durationFor(type), const Duration(minutes: 3));
      }
      for (final type in [GameType.switcher, GameType.math, GameType.strokes]) {
        expect(settings.durationFor(type), Duration(minutes: minutes));
      }
      expect(settings.simulationDuration, Duration(minutes: 6 + minutes * 3));
    }
  });

  group('Spatial transformations', () {
    test(
      'rotation and reflection preserve the complete asymmetric pattern',
      () {
        const pattern = <int>[0, 1, 7];

        expect(rotateCells(pattern, 3, 1), unorderedEquals(<int>{2, 3, 5}));
        expect(rotateCells(pattern, 3, 4), unorderedEquals(pattern));
        expect(
          mirrorCells(pattern, 3, 'vertical'),
          unorderedEquals(<int>{1, 2, 7}),
        );
        expect(
          mirrorCells(pattern, 3, 'horizontal'),
          unorderedEquals(<int>{1, 6, 7}),
        );
      },
    );

    test('two switch filters compose in the displayed order', () {
      final intermediate = applyPermutation(
        <int>[0, 1, 2, 3],
        <int>[1, 3, 4, 2],
      );
      expect(intermediate, <int>[0, 2, 3, 1]);
      expect(applyPermutation(intermediate, <int>[3, 2, 4, 1]), <int>[
        3,
        2,
        1,
        0,
      ]);
    });
  });

  group('Arithmetic', () {
    test('multiplication and division precede addition and subtraction', () {
      expect(evaluateExpression(<int>[8, 2, 3], <String>['+', '×']), 14);
      expect(evaluateExpression(<int>[18, 3, 2], <String>['−', '×']), 12);
      expect(evaluateExpression(<int>[20, 4, 2], <String>['÷', '+']), 7);
    });

    test('operators of equal precedence associate from left to right', () {
      expect(evaluateExpression(<int>[8, 2, 3], <String>['÷', '×']), 12);
      expect(evaluateExpression(<int>[18, 3, 2], <String>['−', '−']), 13);
      expect(evaluateExpression(<int>[3, 2, 4], <String>['/', '*']), 6);
      expect(evaluateExpression(<int>[1, 0], <String>['÷']), isNull);
    });

    test('subtraction keeps the sign of an entire multiplied term', () {
      expect(
        evaluateExpression(<int>[20, 6, 3, 2, 1], <String>['−', '÷', '×', '+']),
        17,
      );
    });

    test('invalid expressions have no numeric answer', () {
      expect(evaluateExpression(<int>[], <String>[]), isNull);
      expect(evaluateExpression(<int>[1, 2, 3], <String>['+']), isNull);
      expect(evaluateExpression(<int>[1, 2], <String>['?']), isNull);
    });

    test('answers must use every available number with its multiplicity', () {
      final question = MathQuestion(
        numbers: <int>[2, 2, 4],
        operators: <String>['+', '×'],
        target: 10,
        solution: '2 + 2 × 4',
      );

      expect(question.check(<int>[2, 2, 4]), isTrue);
      expect(question.check(<int>[2, 4, 2]), isTrue);
      expect(question.check(<int>[6, 1, 4]), isFalse);
      expect(question.check(<int>[10]), isFalse);
      expect(question.check('2 + 2 × 4'), isFalse);
    });
  });

  group('Memory answers', () {
    test('requires all exact positions without omissions or repeated taps', () {
      final question = MemoryQuestion(
        cells: <int>[1, 7, 24],
        previewMilliseconds: 2500,
      );

      expect(question.check(<int>[24, 1, 7]), isTrue);
      expect(question.check(<int>{1, 7, 24}), isTrue);
      expect(question.check(<int>[1, 7]), isFalse);
      expect(question.check(<int>[1, 7, 25]), isFalse);
      expect(question.check(<int>[1, 7, 24, 25]), isFalse);
      expect(question.check(<int>[1, 7, 7]), isFalse);
      expect(question.check(<int>[1, 7, 24, 24]), isFalse);
      expect(question.check(null), isFalse);
    });
  });

  group('Question generation', () {
    test(
      'a seed reproduces every stimulus and solution at either difficulty',
      () {
        for (final type in GameType.values) {
          for (final difficulty in Difficulty.values) {
            final first = QuestionGenerator(random: Random(714));
            final second = QuestionGenerator(random: Random(714));
            for (var number = 1; number <= 40; number++) {
              expect(
                _fingerprint(
                  first.generate(type, difficulty, questionNumber: number),
                ),
                _fingerprint(
                  second.generate(type, difficulty, questionNumber: number),
                ),
                reason: '${type.name}, ${difficulty.name}, question $number',
              );
            }
          }
        }
      },
    );

    test(
      'memory targets stay unique, in bounds and within the exposure window',
      () {
        for (final difficulty in Difficulty.values) {
          final generator = QuestionGenerator(random: Random(37));
          for (var number = 1; number <= 80; number++) {
            final question = generator.generate(
              GameType.memory,
              difficulty,
              questionNumber: number,
            ) as MemoryQuestion;
            expect(question.cells.length, inInclusiveRange(2, 5));
            expect(question.cells.toSet().length, question.cells.length);
            expect(question.cells, everyElement(inInclusiveRange(0, 35)));
            expect(question.previewMilliseconds, inInclusiveRange(2000, 3000));
            expect(question.check(question.cells), isTrue);
          }
        }
      },
    );

    test(
      'grid answers agree with rotation or union and keep symmetry separate',
      () {
        for (final difficulty in Difficulty.values) {
          final generator = QuestionGenerator(random: Random(500));
          final seenTasks = <GridTask>{};
          final seenAnswers = <bool>{};
          for (var number = 1; number <= 180; number++) {
            final question = generator.generate(
              GameType.grid,
              difficulty,
              questionNumber: number,
            ) as GridQuestion;
            seenTasks.add(question.task);
            seenAnswers.add(question.correct);
            final expected = _expectedGrid(question);
            final displayed = question.result ?? question.right;
            final isEqual =
                displayed.toSet().length == expected.length &&
                expected.containsAll(displayed);

            expect(question.correct, isEqual, reason: 'Question $number');
            expect(question.check(isEqual), isTrue);
            expect(question.check(!isEqual), isFalse);
            expect(displayed.toSet().length, displayed.length);
            expect(displayed, everyElement(inInclusiveRange(0, 24)));
          }
          expect(seenTasks, <GridTask>{
            GridTask.rotation,
            GridTask.combination,
          });
          expect(seenAnswers, <bool>{true, false});
        }
      },
    );

    test(
      'symmetry practice independently compares identity and reflections',
      () {
        for (final difficulty in Difficulty.values) {
          final generator = QuestionGenerator(random: Random(501));
          final seenTasks = <GridTask>{};
          for (var number = 1; number <= 120; number++) {
            final question = generator.generate(
              GameType.symmetry,
              difficulty,
              questionNumber: number,
            ) as GridQuestion;
            seenTasks.add(question.task);
            final expected = _expectedGrid(question);
            final displayed = question.right.toSet();
            expect(
              question.correct,
              expected.length == displayed.length &&
                  expected.containsAll(displayed),
            );
            expect(question.check(question.correct), isTrue);
          }
          expect(seenTasks, <GridTask>{GridTask.identity, GridTask.symmetry});
        }
      },
    );

    test('each switch has one and only one valid second filter', () {
      for (final difficulty in Difficulty.values) {
        final generator = QuestionGenerator(random: Random(9));
        for (var number = 1; number <= 100; number++) {
          final question = generator.generate(
            GameType.switcher,
            difficulty,
          ) as SwitchQuestion;
          final matching = <int>[];
          expect(question.input, unorderedEquals(<int>[0, 1, 2, 3]));
          expect(question.firstRule, unorderedEquals(<int>[1, 2, 3, 4]));
          expect(
            question.options.map((rule) => rule.join()).toSet().length,
            question.options.length,
          );
          for (var index = 0; index < question.options.length; index++) {
            final option = question.options[index];
            expect(option, unorderedEquals(<int>[1, 2, 3, 4]));
            final firstOutput = <int>[
              for (final position in question.firstRule)
                question.input[position - 1],
            ];
            final output = <int>[
              for (final position in option) firstOutput[position - 1],
            ];
            if (output.join() == question.output.join()) matching.add(index);
          }
          expect(matching, <int>[question.correctIndex]);
        }
      }
    });

    test(
      'numeric puzzles always provide a solution using the supplied tiles',
      () {
        for (final difficulty in Difficulty.values) {
          final generator = QuestionGenerator(random: Random(123));
          final seenLengths = <int>{};
          for (var number = 1; number <= 120; number++) {
            final question = generator.generate(
              GameType.math,
              difficulty,
              questionNumber: number,
            ) as MathQuestion;
            seenLengths.add(question.numbers.length);
            final solutionNumbers = question.solution
                .split(' = ')
                .first
                .split(' ')
                .indexed
                .where((entry) => entry.$1.isEven)
                .map((entry) => int.parse(entry.$2))
                .toList();
            expect(question.numbers.length, inInclusiveRange(2, 6));
            expect(question.operators.length, question.numbers.length - 1);
            expect(question.numbers, everyElement(inInclusiveRange(1, 9)));
            expect(question.target, inInclusiveRange(1, 999));
            expect(
              question.check(solutionNumbers),
              isTrue,
              reason: question.solution,
            );
          }
          expect(seenLengths, <int>{2, 3, 4, 5, 6});
        }
      },
    );
  });

  group('Round lifecycle', () {
    test('memory ignores answers before the exact exposure deadline', () {
      fakeAsync((async) {
        final controller = RoundController(
          GameType.memory,
          const TrainingSettings(),
          random: Random(1),
          elapsedNow: () => async.elapsed,
          mixedSequences: false,
        );
        final question = controller.currentQuestion as MemoryQuestion;
        final preview = Duration(milliseconds: question.previewMilliseconds);

        async.elapse(preview - const Duration(microseconds: 1));
        controller.submit(question.cells);
        expect(controller.questionNumber, 1);
        expect(controller.isMemorizing, isTrue);
        expect(controller.previewRemaining, const Duration(microseconds: 1));

        async.elapse(const Duration(microseconds: 1));
        controller.submit(question.cells);
        expect(controller.questionNumber, 2);
        expect(controller.isMemorizing, isTrue);
        expect(() => controller.result, throwsStateError);
        controller.finish();
        expect(controller.result.correctCount, 1);
        expect(controller.result.attempts.single.response, preview);
        expect(async.periodicTimerCount, 0);
        controller.dispose();
      });
    });

    test('skipping during memory exposure records one omitted answer', () {
      fakeAsync((async) {
        final controller = RoundController(
          GameType.memory,
          const TrainingSettings(),
          elapsedNow: () => async.elapsed,
          mixedSequences: false,
        );
        controller.skip();
        expect(controller.questionNumber, 2);
        expect(controller.isMemorizing, isTrue);
        controller.finish();
        expect(controller.result.skippedCount, 1);
        expect(controller.result.correctCount, 0);
        controller.dispose();
      });
    });

    test('deadline rejects a late answer and completes just once', () {
      fakeAsync((async) {
        const origin = Duration(hours: 7);
        var now = origin;
        const settings = TrainingSettings();
        final controller = RoundController(
          GameType.grid,
          settings,
          mixedSequences: false,
          random: Random(21),
          elapsedNow: () => now,
        );
        var completionNotifications = 0;
        controller.addListener(() {
          if (controller.isFinished) completionNotifications++;
        });
        expect(controller.remaining.value, controller.duration);

        now = origin + controller.duration - const Duration(microseconds: 1);
        controller.submit((controller.currentQuestion as GridQuestion).correct);
        expect(controller.questionNumber, 2);
        expect(() => controller.result, throwsStateError);

        now = origin + controller.duration;
        controller.submit((controller.currentQuestion as GridQuestion).correct);
        expect(controller.isFinished, isTrue);
        expect(controller.remaining.value, Duration.zero);
        expect(controller.result.attempts.length, 1);
        expect(controller.result.duration, controller.duration);
        final report = controller.result.toJson();

        now += const Duration(minutes: 1);
        controller.finish();
        controller.skip();
        controller.submit(true);
        controller.refresh();
        expect(controller.result.toJson(), report);
        expect(completionNotifications, 1);
        expect(async.periodicTimerCount, 0);
        controller.dispose();
      });
    });

    test('a deadline reached during submission cannot record or advance', () {
      fakeAsync((async) {
        const duration = Duration(minutes: 3);
        var clockReads = 0;
        final controller = RoundController(
          GameType.grid,
          const TrainingSettings(),
          mixedSequences: false,
          elapsedNow: () => switch (clockReads++) {
            0 => Duration.zero,
            1 => duration - const Duration(microseconds: 1),
            _ => duration,
          },
        );

        controller.submit((controller.currentQuestion as GridQuestion).correct);
        expect(controller.isFinished, isTrue);
        expect(controller.questionNumber, 1);
        expect(controller.result.attempts, isEmpty);
        expect(controller.result.duration, duration);
        expect(async.periodicTimerCount, 0);
        controller.dispose();
      });
    });

    test('a delayed timer uses elapsed time and clamps the final duration', () {
      fakeAsync((async) {
        const settings = TrainingSettings(roundMinutes: 6);
        final controller = RoundController(
          GameType.math,
          settings,
          elapsedNow: () => async.elapsed,
        );

        async.elapseBlocking(controller.duration + const Duration(seconds: 37));
        async.elapse(const Duration(milliseconds: 1));
        expect(controller.isFinished, isTrue);
        expect(controller.result.duration, controller.duration);
        expect(controller.remaining.value, Duration.zero);
        expect(controller.result.attempts, isEmpty);
        expect(async.periodicTimerCount, 0);
        controller.dispose();
      });
    });

    test(
      'feedback waits until finish and response times reset for each question',
      () {
        fakeAsync((async) {
          final controller = RoundController(
            GameType.grid,
            const TrainingSettings(),
            mixedSequences: false,
            random: Random(11),
            elapsedNow: () => async.elapsed,
          );
          expect(() => controller.result, throwsStateError);
          expect(() => controller.attempts, throwsStateError);
          async.elapse(const Duration(milliseconds: 200));
          controller.submit(
            (controller.currentQuestion as GridQuestion).correct,
          );
          expect(() => controller.result, throwsStateError);
          expect(() => controller.attempts, throwsStateError);
          async.elapse(const Duration(milliseconds: 700));
          controller.submit(
            !(controller.currentQuestion as GridQuestion).correct,
          );
          async.elapse(const Duration(milliseconds: 300));
          controller.skip();
          controller.finish();
          final result = controller.result;

          expect(controller.attempts.length, 3);
          expect(result.correctCount, 1);
          expect(result.skippedCount, 1);
          expect(result.answeredCount, 2);
          expect(result.accuracy, closeTo(1 / 3, .0000001));
          expect(result.averageResponseSeconds, closeTo(.4, .0000001));
          expect(
            result.attempts.map((attempt) => attempt.response.inMilliseconds),
            <int>[200, 700, 300],
          );
          expect(result.duration, const Duration(milliseconds: 1200));
          expect(() => result.attempts.clear(), throwsUnsupportedError);
          controller.dispose();
        });
      },
    );

    test('disposing cancels timers and future updates', () {
      fakeAsync((async) {
        final controller = RoundController(
          GameType.memory,
          const TrainingSettings(),
          elapsedNow: () => async.elapsed,
        );
        var notifications = 0;
        controller.addListener(() => notifications++);
        controller.remaining.addListener(() => notifications++);
        expect(async.periodicTimerCount, 1);
        controller.dispose();

        async.elapse(const Duration(minutes: 10));
        expect(async.periodicTimerCount, 0);
        expect(notifications, 0);
      });
    });
  });

  group('Saved reports', () {
    test('serialization retains per-answer feedback and subsecond timings', () {
      final result = RoundResult(
        type: GameType.math,
        date: DateTime.utc(2026, 10, 20, 12),
        duration: const Duration(minutes: 5),
        attempts: const <Attempt>[
          Attempt(
            prompt: 'Ordena las fichas',
            given: '2 + 2 × 4',
            expected: '2 + 2 × 4',
            correct: true,
            skipped: false,
            response: Duration(milliseconds: 1500),
          ),
          Attempt(
            prompt: 'Ordena las fichas',
            given: 'Sin respuesta',
            expected: '2 + 2 × 4',
            correct: false,
            skipped: true,
            response: Duration(milliseconds: 500),
          ),
        ],
      );
      final restored = RoundResult.fromJson(result.toJson());

      expect(restored.type, result.type);
      expect(restored.date, result.date);
      expect(restored.duration, result.duration);
      expect(restored.attempts.last.skipped, isTrue);
      expect(restored.attempts.first.given, '2 + 2 × 4');
      expect(restored.attempts.first.expected, '2 + 2 × 4');
      expect(restored.correctCount, 1);
      expect(restored.skippedCount, 1);
      expect(restored.answeredCount, 1);
      expect(restored.accuracy, .5);
      expect(restored.averageResponseSeconds, 1);
    });

    test('an unanswered round has finite zero metrics', () {
      final result = RoundResult(
        type: GameType.grid,
        date: DateTime.utc(2026, 10, 20),
        duration: Duration.zero,
        attempts: const <Attempt>[],
      );

      expect(result.accuracy, 0);
      expect(result.averageResponseSeconds, 0);
      expect(result.answeredCount, 0);
    });
  });
}

List<Object?> _fingerprint(Question question) => switch (question) {
  MemoryQuestion() => <Object?>[
    question.cells,
    question.gridSize,
    question.previewMilliseconds,
  ],
  GridQuestion() => <Object?>[
    question.task,
    question.left,
    question.right,
    question.result,
    question.size,
    question.correct,
    question.quarterTurns,
    question.symmetryAxis,
  ],
  SwitchQuestion() => <Object?>[
    question.input,
    question.firstRule,
    question.output,
    question.options,
    question.correctIndex,
  ],
  MathQuestion() => <Object?>[
    question.numbers,
    question.operators,
    question.target,
    question.solution,
  ],
  StrokeEquationQuestion() => [
    question.left,
    question.right,
    question.result,
    question.correct,
  ],
  _ => throw StateError('Unsupported question type: ${question.runtimeType}'),
};

Set<int> _expectedGrid(GridQuestion question) {
  if (question.task == GridTask.identity) return question.left.toSet();
  if (question.task == GridTask.combination) {
    return <int>{...question.left, ...question.right};
  }
  final size = question.size;
  return question.left.map((cell) {
    final row = cell ~/ size;
    final column = cell % size;
    if (question.task == GridTask.symmetry) {
      return question.symmetryAxis == 'vertical'
          ? row * size + size - 1 - column
          : (size - 1 - row) * size + column;
    }
    return switch (question.quarterTurns % 4) {
      0 => cell,
      1 => column * size + size - 1 - row,
      2 => (size - 1 - row) * size + size - 1 - column,
      3 => (size - 1 - column) * size + row,
      _ => throw StateError('Unreachable turn count'),
    };
  }).toSet();
}
