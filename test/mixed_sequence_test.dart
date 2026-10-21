import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/domain/mixed_sequence_controller.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:pg_prep_mobile/domain/question_generator.dart';
import 'package:pg_prep_mobile/domain/round_controller.dart';

void main() {
  group('Ordered memory', () {
    test(
      'legacy templates retain exact ordered checking and immutable targets',
      () {
        final question = MemorySequenceQuestion(
          templateCells: [0, 2, 7, 13, 20],
          sequence: [7, 2, 13],
        );
        expect(question.check([7, 2, 13]), isTrue);
        for (final wrong in <Object>[
          [2, 7, 13],
          [7, 2],
          [7, 2, 2],
          [7, 2, 13, 20],
          <int>{7, 2, 13},
        ]) {
          expect(question.check(wrong), isFalse);
        }
        expect(question.correctAnswerLabel, '2:2 → 1:3 → 3:2');
        expect(question.answerLabel([13, 2, 7]), '3:2 → 1:3 → 2:2');
        expect(question.hasScatteredLayout, isFalse);
        expect(() => question.sequence.add(20), throwsUnsupportedError);
        expect(() => question.templateCells.clear(), throwsUnsupportedError);
      },
    );

    test(
      'invalid templates and targets cannot create an unanswerable task',
      () {
        for (final (template, sequence) in <(List<int>, List<int>)>[
          ([0, 0, 1], [0, 1]),
          ([0, 1, 36], [0, 1]),
          ([0, 1, 2], [0, 3]),
          ([0, 1, 2], [0, 0]),
          ([0, 1, 2], []),
        ]) {
          expect(
            () => MemorySequenceQuestion(
              templateCells: template,
              sequence: sequence,
            ),
            throwsArgumentError,
          );
        }
        for (final positions in <Map<int, Point<double>>>[
          {0: const Point(.2, .3)},
          {0: const Point(.2, .3), 1: const Point(1, .5)},
          {0: const Point(.2, .3), 1: const Point(double.nan, .5)},
        ]) {
          expect(
            () => MemorySequenceQuestion(
              templateCells: [0, 1],
              sequence: [1],
              positions: positions,
            ),
            throwsArgumentError,
          );
        }
      },
    );

    test('seeded scattered templates vary positions and sequence, with three to five targets', () {
      for (final difficulty in Difficulty.values) {
        final first = QuestionGenerator(random: Random(28));
        final second = QuestionGenerator(random: Random(28));
        MemorySequenceQuestion? previous;
        for (var cycle = 1; cycle <= 30; cycle++) {
          final memory = first.generateMemorySequence(
            difficulty,
            cycleNumber: cycle,
          );
          final same = second.generateMemorySequence(
            difficulty,
            cycleNumber: cycle,
          );
          expect(memory.templateCells, same.templateCells);
          expect(memory.sequence, same.sequence);
          expect(memory.positions, same.positions);
          expect(memory.hasScatteredLayout, isTrue);
          expect(memory.templateCells.length, 24);
          expect(memory.templateCells.toSet().length, 24);
          expect(memory.templateCells, everyElement(inInclusiveRange(0, 35)));
          expect(memory.sequence.length, min(5, cycle + 2));
          expect(memory.sequence.toSet().length, memory.sequence.length);
          expect(memory.templateCells, containsAll(memory.sequence));
          expect(memory.positions.keys.toSet(), memory.templateCells.toSet());
          for (final point in memory.positions.values) {
            expect(point.x, greaterThan(0));
            expect(point.x, lessThan(1));
            expect(point.y, greaterThan(0));
            expect(point.y, lessThan(1));
          }
          final points = memory.positions.values.toList();
          for (var i = 0; i < points.length; i++) {
            for (var j = i + 1; j < points.length; j++) {
              expect(
                points[i].distanceTo(points[j]),
                greaterThanOrEqualTo(.12),
              );
            }
          }
          expect(
            memory.templateCells.any(
              (cell) =>
                  memory.positionFor(cell) !=
                  Point((cell % 6 + .5) / 6, (cell ~/ 6 + .5) / 6),
            ),
            isTrue,
          );
          expect(() => memory.positions.clear(), throwsUnsupportedError);
          if (previous != null) {
            expect(memory.positions, isNot(previous.positions));
            expect(memory.sequence, isNot(previous.sequence));
          }
          previous = memory;
        }
      }
    });
  });

  group('Mixed rounds', () {
    for (final type in [GameType.grid, GameType.symmetry, GameType.mixed]) {
      for (final difficulty in Difficulty.values) {
        test(
          '${type.name}/${difficulty.name} starts with a point and reasons after every point including the last',
          () {
            fakeAsync((clock) {
              final recorded = <Attempt>[];
              final controller = RoundController(
                type,
                TrainingSettings(difficulty: difficulty),
                random: Random(8),
                elapsedNow: () => clock.elapsed,
                onAttempt: recorded.add,
              );
              final memory = controller.mixedSequence!;
              expect(controller.isMixed, isTrue);
              expect(controller.sequenceLength, 3);
              final observed = <int>[];
              final reasoning = <GameType>[];
              for (var index = 0; index < memory.sequence.length; index++) {
                expect(controller.mixedPhase, MixedPhase.flash);
                final flash = controller.currentQuestion as PointFlashQuestion;
                expect(flash.memory, same(memory));
                expect(flash.templateCells, same(memory.templateCells));
                expect(flash.cell, memory.sequence[index]);
                expect(flash.index, index);
                expect(flash.total, 3);
                expect(flash.durationMilliseconds, 3500);
                observed.add(flash.cell);
                final questionNumber = controller.questionNumber;
                controller.skip();
                controller.submit(true);
                expect(controller.questionNumber, questionNumber);
                clock.elapse(const Duration(milliseconds: 3499));
                controller.refresh();
                expect(controller.mixedPhase, MixedPhase.flash);
                expect(
                  controller.phaseRemaining.value,
                  const Duration(milliseconds: 1),
                );
                clock.elapse(const Duration(milliseconds: 1));
                expect(controller.mixedPhase, MixedPhase.reasoning);
                expect(controller.phaseDuration, const Duration(seconds: 5));
                reasoning.add(controller.reasoningType);
                final question = controller.currentQuestion as GridQuestion;
                clock.elapse(const Duration(milliseconds: 250));
                controller.submit(question.correct);
                expect(
                  controller.mixedPhase,
                  index == 2 ? MixedPhase.recall : MixedPhase.flash,
                );
                expect(() => controller.attempts, throwsStateError);
                expect(() => controller.result, throwsStateError);
              }
              expect(observed, memory.sequence);
              expect(controller.currentQuestion, same(memory));
              expect(
                reasoning,
                type == GameType.mixed
                    ? [GameType.grid, GameType.symmetry, GameType.grid]
                    : List.filled(3, type),
              );
              clock.elapse(const Duration(milliseconds: 900));
              controller.submit(observed);
              expect(controller.mixedPhase, MixedPhase.flash);
              expect(controller.sequenceLength, 4);
              expect(controller.mixedCycle, 2);
              expect(controller.mixedSequence, isNot(same(memory)));
              controller.finish();
              expect(controller.result.correctCount, 4);
              expect(controller.result.attempts.length, 4);
              expect(recorded.length, 4);
              expect(
                controller.result.attempts.last.expected,
                memory.correctAnswerLabel,
              );
              expect(
                controller.result.attempts.last.response,
                const Duration(milliseconds: 900),
              );
              expect(clock.periodicTimerCount, 0);
              expect(clock.nonPeriodicTimerCount, 0);
              controller.dispose();
            });
          },
        );
      }
    }

    test('memory-only mode presents three, four and five consecutive points before ordered recall', () {
      fakeAsync((clock) {
        final controller = RoundController(
          GameType.memory,
          const TrainingSettings(),
          random: Random(71),
          elapsedNow: () => clock.elapsed,
        );
        for (var cycle = 1; cycle <= 4; cycle++) {
          final memory = controller.mixedSequence!;
          expect(memory.sequence.length, min(5, cycle + 2));
          for (final cell in memory.sequence) {
            expect(controller.mixedPhase, MixedPhase.flash);
            expect(controller.flashCell, cell);
            clock.elapse(const Duration(milliseconds: 3500));
          }
          expect(controller.mixedPhase, MixedPhase.recall);
          controller.submit(memory.sequence);
        }
        controller.finish();
        expect(controller.result.attempts.length, 4);
        expect(controller.result.correctCount, 4);
        controller.dispose();
      });
    });

    test('five-second reasoning deadline records an omission and continues with the next point', () {
      fakeAsync((clock) {
        final recorded = <Attempt>[];
        final controller = RoundController(
          GameType.grid,
          const TrainingSettings(),
          elapsedNow: () => clock.elapsed,
          onAttempt: recorded.add,
        );
        clock.elapse(const Duration(milliseconds: 3500));
        clock.elapse(const Duration(milliseconds: 4999));
        controller.refresh();
        expect(controller.mixedPhase, MixedPhase.reasoning);
        expect(
          controller.phaseRemaining.value,
          const Duration(milliseconds: 1),
        );
        expect(recorded, isEmpty);
        clock.elapse(const Duration(milliseconds: 1));
        expect(recorded.length, 1);
        expect(recorded.single.skipped, isTrue);
        expect(recorded.single.correct, isFalse);
        expect(recorded.single.response, const Duration(seconds: 5));
        expect(controller.mixedPhase, MixedPhase.flash);
        expect(controller.sequenceIndex, 1);
        controller.dispose();
      });
    });

    test('recall expires at five seconds, retaining partial selected order for the report', () {
      fakeAsync((clock) {
        final recorded = <Attempt>[];
        final controller = RoundController(
          GameType.memory,
          const TrainingSettings(),
          elapsedNow: () => clock.elapsed,
          onAttempt: recorded.add,
        );
        final memory = controller.mixedSequence!;
        clock.elapse(const Duration(milliseconds: 10500));
        expect(controller.mixedPhase, MixedPhase.recall);
        final partial = memory.sequence.take(2).toList();
        controller.setRecallSelection(partial);
        partial.clear(); // The controller must retain its own snapshot.
        clock.elapse(const Duration(milliseconds: 4999));
        expect(recorded, isEmpty);
        expect(controller.mixedPhase, MixedPhase.recall);
        clock.elapse(const Duration(milliseconds: 1));
        expect(recorded.length, 1);
        expect(recorded.single.skipped, isTrue);
        expect(
          recorded.single.given,
          memory.answerLabel(memory.sequence.take(2).toList()),
        );
        expect(recorded.single.expected, memory.correctAnswerLabel);
        expect(recorded.single.response, const Duration(seconds: 5));
        expect(controller.mixedPhase, MixedPhase.flash);
        expect(controller.sequenceLength, 4);
        controller.dispose();
      });
    });

    test('recall with the same set in reversed order fails without immediate public feedback', () {
      fakeAsync((clock) {
        final controller = RoundController(
          GameType.grid,
          const TrainingSettings(),
          random: Random(71),
          elapsedNow: () => clock.elapsed,
        );
        final memory = controller.mixedSequence!;
        for (var i = 0; i < memory.sequence.length; i++) {
          clock.elapse(controller.flashDuration);
          controller.submit(
            (controller.currentQuestion as GridQuestion).correct,
          );
        }
        controller.submit(memory.sequence.reversed.toList());
        expect(() => controller.result, throwsStateError);
        controller.finish();
        expect(controller.result.correctCount, memory.sequence.length);
        expect(controller.result.attempts.last.correct, isFalse);
        expect(controller.result.attempts.last.skipped, isFalse);
        controller.dispose();
      });
    });

    test('a complete recall selection is evaluated when its five-second window closes', () {
      for (final reverse in [false, true]) {
        fakeAsync((clock) {
          final recorded = <Attempt>[];
          final controller = RoundController(
            GameType.memory,
            const TrainingSettings(),
            elapsedNow: () => clock.elapsed,
            onAttempt: recorded.add,
          );
          final memory = controller.mixedSequence!;
          clock.elapse(const Duration(milliseconds: 10500));
          final selected = reverse
              ? memory.sequence.reversed.toList()
              : memory.sequence;
          controller.setRecallSelection(selected);
          clock.elapse(const Duration(seconds: 5));
          expect(recorded.length, 1);
          expect(recorded.single.skipped, isFalse);
          expect(recorded.single.correct, !reverse);
          expect(recorded.single.given, memory.answerLabel(selected));
          expect(recorded.single.response, const Duration(seconds: 5));
          expect(controller.mixedPhase, MixedPhase.flash);
          controller.dispose();
        });
      }
    });

    test('stale input at a flash deadline cannot answer the newly opened reasoning task', () {
      fakeAsync((clock) {
        var now = Duration.zero;
        final recorded = <Attempt>[];
        final controller = RoundController(
          GameType.grid,
          const TrainingSettings(),
          elapsedNow: () => now,
          onAttempt: recorded.add,
        );
        now += const Duration(milliseconds: 3500);
        controller.submit(true);
        expect(controller.mixedPhase, MixedPhase.reasoning);
        expect(recorded, isEmpty);
        controller.dispose();
      });
    });

    test('late reasoning and recall input expires the old phase without answering the next one', () {
      for (final type in [GameType.grid, GameType.memory]) {
        fakeAsync((clock) {
          var now = Duration.zero;
          final recorded = <Attempt>[];
          final controller = RoundController(
            type,
            const TrainingSettings(),
            elapsedNow: () => now,
            onAttempt: recorded.add,
          );
          final count = type == GameType.memory ? controller.sequenceLength : 1;
          for (var index = 0; index < count; index++) {
            now += const Duration(milliseconds: 3500);
            controller.refresh();
          }
          final question = controller.currentQuestion;
          now += const Duration(seconds: 5);
          controller.submit(
            question is GridQuestion
                ? question.correct
                : (question as MemorySequenceQuestion).sequence,
          );
          expect(recorded.length, 1);
          expect(recorded.single.skipped, isTrue);
          expect(recorded.single.correct, isFalse);
          expect(controller.mixedPhase, MixedPhase.flash);
          controller.dispose();
        });
      }
    });

    test('a delayed refresh advances one phase and gives the next task a full deadline', () {
      fakeAsync((clock) {
        var now = Duration.zero;
        final recorded = <Attempt>[];
        final controller = RoundController(
          GameType.symmetry,
          const TrainingSettings(),
          elapsedNow: () => now,
          onAttempt: recorded.add,
        );
        now += const Duration(seconds: 30);
        controller.refresh();
        expect(controller.mixedPhase, MixedPhase.reasoning);
        expect(controller.sequenceIndex, 0);
        expect(controller.phaseRemaining.value, const Duration(seconds: 5));
        controller.refresh();
        expect(recorded, isEmpty);
        controller.finish();
        expect(controller.result.duration, const Duration(seconds: 30));
        controller.dispose();
      });
    });

    test('round expiry during a flash cancels clocks and preserves recorded responses', () {
      fakeAsync((clock) {
        var now = Duration.zero;
        final controller = RoundController(
          GameType.grid,
          const TrainingSettings(),
          elapsedNow: () => now,
        );
        now = const Duration(milliseconds: 3500);
        controller.refresh();
        controller.skip();
        expect(controller.mixedPhase, MixedPhase.flash);
        now = const Duration(minutes: 6);
        controller.refresh();
        expect(controller.isFinished, isTrue);
        expect(controller.result.duration, const Duration(minutes: 3));
        expect(controller.result.skippedCount, 1);
        expect(controller.result.attempts.length, 1);
        expect(controller.flashRemaining, Duration.zero);
        expect(clock.periodicTimerCount, 0);
        expect(clock.nonPeriodicTimerCount, 0);
        controller.dispose();
      });
    });

    test(
      'disposing during a flash cancels callbacks and blocks late input',
      () {
        fakeAsync((clock) {
          final recorded = <Attempt>[];
          final controller = RoundController(
            GameType.grid,
            const TrainingSettings(),
            elapsedNow: () => clock.elapsed,
            onAttempt: recorded.add,
          );
          expect(clock.nonPeriodicTimerCount, 1);
          controller.dispose();
          final number = controller.questionNumber;
          clock.elapse(const Duration(minutes: 10));
          controller.refresh();
          controller.submit(true);
          controller.skip();
          controller.finish();
          expect(controller.questionNumber, number);
          expect(recorded, isEmpty);
          expect(clock.periodicTimerCount, 0);
          expect(clock.nonPeriodicTimerCount, 0);
        });
      },
    );

    test('sequencer rejects games without point sequences', () {
      for (final type in [GameType.math, GameType.switcher, GameType.strokes]) {
        expect(
          () => MixedSequenceController(
            type: type,
            difficulty: Difficulty.advanced,
            generator: QuestionGenerator(),
          ),
          throwsArgumentError,
        );
      }
    });
  });
}
