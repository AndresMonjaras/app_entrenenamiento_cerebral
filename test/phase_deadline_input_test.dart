import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:pg_prep_mobile/domain/round_controller.dart';

void main() {
  test(
    'a released old reasoning button cannot answer the new recovery phase',
    () {
      fakeAsync((clock) {
        final attempts = <Attempt>[];
        final controller = RoundController(
          GameType.grid,
          const TrainingSettings(),
          elapsedNow: () => clock.elapsed,
          onAttempt: attempts.add,
        );
        final count = controller.sequenceLength;
        for (var i = 0; i < count; i++) {
          clock.elapse(const Duration(milliseconds: 3500));
          final question = controller.currentQuestion as GridQuestion;
          if (i + 1 < count) {
            controller.submit(question.correct, expectedQuestion: question);
          } else {
            clock.elapse(const Duration(seconds: 5));
            expect(controller.mixedPhase, MixedPhase.recall);
            final recovery = controller.currentQuestion;
            final count = attempts.length;
            controller.submit(true, expectedQuestion: question);
            controller.submit(true);
            expect(controller.currentQuestion, same(recovery));
            expect(attempts.length, count);
            controller.submit(
              (recovery as MemorySequenceQuestion).sequence,
              expectedQuestion: recovery,
            );
            expect(attempts.last.correct, isTrue);
            expect(controller.mixedPhase, MixedPhase.flash);
          }
        }
        controller.dispose();
      });
    },
  );
}
