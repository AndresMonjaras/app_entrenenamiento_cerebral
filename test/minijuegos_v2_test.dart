import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:pg_prep_mobile/features/minijuegos/common/mini_result.dart';
import 'package:pg_prep_mobile/features/minijuegos/hub/mini_progress_store.dart';
import 'package:pg_prep_mobile/features/minijuegos/hub/mini_session_controller.dart';
import 'package:pg_prep_mobile/features/minijuegos/memoria_progresiva/memoria_progresiva_screen.dart';
import 'package:pg_prep_mobile/features/minijuegos/mixto_v2/mixto_v2_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _attempt = Attempt(
  prompt: 'Ejercicio',
  given: 'Sí',
  expected: 'Sí',
  correct: true,
  skipped: false,
  response: Duration(seconds: 1),
);

class _PreferenceState {
  Completer<void>? gate;
  bool fail = false;
}

class _Preferences implements SharedPreferencesAsync {
  final values = <String, String>{};
  final state = _PreferenceState();
  Completer<void>? get gate => state.gate;
  set gate(Completer<void>? value) => state.gate = value;
  bool get fail => state.fail;
  set fail(bool value) => state.fail = value;
  @override
  Future<String?> getString(String key) async {
    await gate?.future;
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    if (fail) throw StateError('disk');
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MiniSessionResult _session(int day) => MiniSessionResult(
  date: DateTime(2026, 10, day),
  rounds: [
    MiniRoundResult(
      game: MiniGame.mixed,
      startedAt: DateTime(2026, 10, day),
      duration: const Duration(seconds: 4),
      attempts: [_attempt],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Mixto starts with a 3.5-second point and reasons after every point before ordered collection', () {
    fakeAsync((clock) {
      final recorded = <Attempt>[];
      final controller = MixtoV2Controller(
        random: Random(9),
        elapsedNow: () => clock.elapsed,
        onAttempt: recorded.add,
      );
      final order = <int>[];
      MemorySequenceQuestion? memory;
      for (var i = 0; i < 3; i++) {
        expect(controller.phase, MixedV2Phase.flash);
        final flash = controller.question as PointFlashQuestion;
        memory ??= flash.memory;
        expect(flash.memory, same(memory));
        order.add(flash.cell);
        expect(flash.durationMilliseconds, 3500);
        controller.answer(true);
        expect(recorded.length, i);
        clock.elapse(const Duration(milliseconds: 3499));
        expect(controller.phase, MixedV2Phase.flash);
        clock.elapse(const Duration(milliseconds: 1));
        expect(controller.phase, MixedV2Phase.reasoning);
        expect(
          controller.reasoningType,
          i.isEven ? GameType.grid : GameType.symmetry,
        );
        final question = controller.question as GridQuestion;
        clock.elapse(const Duration(milliseconds: 200));
        controller.answer(question.correct);
      }
      expect(controller.phase, MixedV2Phase.recall);
      final recall = controller.question as MemorySequenceQuestion;
      expect(recall.sequence, order);
      expect(recall, same(memory));
      expect(recall.templateCells.length, 24);
      expect(recall.templateCells, containsAll(order));
      expect(recall.positions, memory!.positions);
      clock.elapse(const Duration(seconds: 1));
      controller.answer(order.reversed.toList());
      expect(recorded.last.correct, isFalse);
      expect(recorded.last.response, const Duration(seconds: 1));
      expect(recorded.take(3).every((a) => a.correct), isTrue);
      expect(controller.cycle, 2);
      expect(controller.sequenceLength, 4);
      expect(controller.phase, MixedV2Phase.flash);
      controller.dispose();
      expect(clock.periodicTimerCount, 0);
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });

  for (final mode in MixedV2Mode.values) {
    test(
      'Mixto $mode progresses through three, four and five targets without scoring flashes',
      () {
        fakeAsync((clock) {
          final controller = MixtoV2Controller(
            mode: mode,
            random: Random(22),
            elapsedNow: () => clock.elapsed,
          );
          var responses = 0;
          for (var cycle = 1; cycle <= 5; cycle++) {
            final seen = <int>[];
            final count = controller.sequenceLength;
            expect(count, min(5, cycle + 2));
            for (var i = 0; i < count; i++) {
              expect(controller.phase, MixedV2Phase.flash);
              seen.add((controller.question as PointFlashQuestion).cell);
              clock.elapse(MixtoV2Controller.flashDuration);
              expect(controller.phase, MixedV2Phase.reasoning);
              if (mode != MixedV2Mode.alternating) {
                expect(
                  controller.reasoningType,
                  mode == MixedV2Mode.grid ? GameType.grid : GameType.symmetry,
                );
              }
              controller.answer((controller.question as GridQuestion).correct);
              responses++;
            }
            expect(controller.phase, MixedV2Phase.recall);
            expect(seen.toSet().length, count);
            controller.answer(seen);
            responses++;
            expect(controller.completedAttempts.length, responses);
            expect(
              controller.completedAttempts.every((a) => a.correct),
              isTrue,
            );
          }
          expect(controller.sequenceLength, 5);
          controller.dispose();
          expect(clock.periodicTimerCount, 0);
          expect(clock.nonPeriodicTimerCount, 0);
        });
      },
    );
  }

  test('Mixto enforces five-second reasoning and recall deadlines without scoring a point', () {
    fakeAsync((clock) {
      final recorded = <Attempt>[];
      final controller = MixtoV2Controller(
        elapsedNow: () => clock.elapsed,
        onAttempt: recorded.add,
      );
      for (var i = 0; i < 3; i++) {
        clock.elapse(const Duration(milliseconds: 3500));
        expect(controller.phase, MixedV2Phase.reasoning);
        clock.elapse(const Duration(milliseconds: 4999));
        expect(recorded.length, i);
        clock.elapse(const Duration(milliseconds: 1));
        expect(recorded.length, i + 1);
        expect(recorded.last.skipped, isTrue);
        expect(recorded.last.response, const Duration(seconds: 5));
      }
      expect(controller.phase, MixedV2Phase.recall);
      clock.elapse(const Duration(milliseconds: 4999));
      expect(recorded.length, 3);
      clock.elapse(const Duration(milliseconds: 1));
      expect(recorded.length, 4);
      expect(recorded.last.skipped, isTrue);
      expect(recorded.last.given, 'Omitida');
      expect(controller.phase, MixedV2Phase.flash);
      expect(controller.cycle, 2);
      controller.dispose();
    });
  });

  test(
    'early refresh cannot end a point and late refresh advances only once',
    () {
      fakeAsync((clock) {
        var now = Duration.zero;
        final controller = MixtoV2Controller(elapsedNow: () => now);
        clock.elapse(MixtoV2Controller.flashDuration);
        expect(controller.phase, MixedV2Phase.flash);
        now = const Duration(seconds: 10);
        controller.refresh();
        expect(controller.phase, MixedV2Phase.reasoning);
        controller.refresh();
        expect(controller.phase, MixedV2Phase.reasoning);
        expect(controller.completedAttempts, isEmpty);
        controller.dispose();
        clock.elapse(const Duration(minutes: 10));
        expect(clock.periodicTimerCount, 0);
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );

  test('session starts after acceptance, uses elapsed time, and rejects late responses', () {
    fakeAsync((clock) {
      final controller = MiniSessionController(
        games: [MiniGame.switchV2, MiniGame.mixed],
        roundDuration: const Duration(seconds: 2),
        elapsedNow: () => clock.elapsed,
      );
      clock.elapse(const Duration(minutes: 10));
      expect(controller.phase, MiniSessionPhase.instructions);
      expect(controller.remaining.value, const Duration(seconds: 2));
      controller.start();
      controller.record(_attempt);
      controller.nextSwitchQuestion();
      expect(controller.questionVersion, 1);
      clock.elapse(const Duration(seconds: 2));
      expect(controller.phase, MiniSessionPhase.instructions);
      expect(controller.game, MiniGame.mixed);
      controller.finishRound();
      clock.elapse(const Duration(minutes: 5));
      expect(controller.phase, MiniSessionPhase.instructions);
      controller.start();
      controller.record(_attempt);
      clock.elapse(const Duration(seconds: 1));
      controller.finishRound();
      controller.finishRound();
      final result = controller.result;
      expect(result.rounds.length, 2);
      expect(result.attempts.length, 2);
      expect(result.duration, const Duration(seconds: 3));
      controller.record(_attempt);
      expect(controller.result.attempts.length, 2);
      controller.dispose();
      expect(clock.periodicTimerCount, 0);
    });
  });

  test(
    'wall clock jump finishes once and cannot accept an answer at the deadline',
    () {
      var now = Duration.zero;
      final controller = MiniSessionController(
        games: [MiniGame.chimp],
        elapsedNow: () => now,
      );
      controller.start();
      now = const Duration(hours: 1);
      controller.record(_attempt);
      expect(controller.phase, MiniSessionPhase.complete);
      expect(controller.result.attempts, isEmpty);
      expect(controller.result.duration, const Duration(minutes: 5));
      controller.refresh();
      expect(controller.result.rounds.length, 1);
      controller.dispose();
    },
  );

  test(
    'aggregate accuracy is weighted by answers and survives JSON round trip',
    () {
      final session = MiniSessionResult(
        date: DateTime(2026),
        rounds: [
          _session(1).rounds.single,
          MiniRoundResult(
            game: MiniGame.chimp,
            startedAt: DateTime(2026),
            duration: const Duration(seconds: 2),
            attempts: List.generate(
              3,
              (_) => const Attempt(
                prompt: 'Orden',
                given: '2 1',
                expected: '1 2',
                correct: false,
                skipped: false,
                response: Duration(seconds: 2),
              ),
            ),
          ),
        ],
      );
      final restored = MiniSessionResult.fromJson(
        jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
      );
      expect(restored.accuracy, .25);
      expect(restored.attempts.length, 4);
      expect(restored.duration, const Duration(seconds: 6));
      expect(() => restored.rounds.clear(), throwsUnsupportedError);
    },
  );

  test('history waits for startup, serializes saves, and preserves the original key', () async {
    final prefs = _Preferences()
      ..gate = Completer<void>()
      ..values['pg_prep.history.v1'] = 'original'
      ..values[MiniProgressStore.storageKey] = jsonEncode([
        _session(1).toJson(),
        {'broken': true},
      ]);
    final store = MiniProgressStore(preferences: prefs);
    final load = store.initialize();
    final first = store.add(_session(2));
    final second = store.add(_session(3));
    prefs.gate!.complete();
    await Future.wait([load, first, second]);
    expect(store.sessions.map((s) => s.date.day), [3, 2, 1]);
    expect(prefs.values['pg_prep.history.v1'], 'original');
    expect(
      jsonDecode(prefs.values[MiniProgressStore.storageKey]!),
      hasLength(3),
    );
    final restored = MiniProgressStore(preferences: prefs);
    await restored.initialize();
    expect(restored.sessions.length, 3);
    store.dispose();
    restored.dispose();
  });

  test(
    'failed history save retains the session and a later save recovers it',
    () async {
      final prefs = _Preferences()..fail = true;
      final store = MiniProgressStore(preferences: prefs);
      await store.add(_session(1));
      expect(store.sessions.length, 1);
      expect(store.error, isNotNull);
      prefs.fail = false;
      await store.add(_session(2));
      expect(store.error, isNull);
      expect(
        jsonDecode(prefs.values[MiniProgressStore.storageKey]!),
        hasLength(2),
      );
      store.dispose();
    },
  );

  test('progressive starts with three, grants life after six, retries and ends safely at board capacity', () {
    fakeAsync((clock) {
      final attempts = <Attempt>[];
      final controller = MemoriaProgresivaController(
        rng: Random(31),
        onAttempt: attempts.add,
      );
      void respond({bool wrong = false}) {
        clock.elapse(const Duration(milliseconds: 2500));
        final cells = controller.cellToNumber.keys.toList()
          ..sort(
            (a, b) => controller.cellToNumber[a]!.compareTo(
              controller.cellToNumber[b]!,
            ),
          );
        for (final cell in wrong ? cells.reversed : cells) {
          controller.tapCell(cell);
        }
        controller.advance();
      }

      expect(controller.elementsCount, 3);
      for (var i = 0; i < 6; i++) {
        respond();
      }
      expect(controller.level, 7);
      expect(controller.hasExtraLife, isTrue);
      final previous = Map.of(controller.cellToNumber);
      respond(wrong: true);
      expect(controller.level, 7);
      expect(controller.hasExtraLife, isFalse);
      expect(controller.cellToNumber, isNot(previous));
      expect(attempts.last.correct, isFalse);
      while (!controller.gameOver) {
        respond();
      }
      expect(attempts.last.correct, isTrue);
      expect(controller.level, 19);
      controller.dispose();
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });
}
