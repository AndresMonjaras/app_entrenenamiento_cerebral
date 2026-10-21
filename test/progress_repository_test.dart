import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/data/progress_repository.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _settingsKey = 'pg_prep.settings.v1';
const _historyKey = 'pg_prep.history.v1';

class _StorageState {
  final Map<String, Object?> values = {};
  Completer<void>? readGate;
  bool failWrites = false;
}

class _TestPreferences implements SharedPreferencesAsync {
  _TestPreferences(this.state);

  final _StorageState state;

  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) async {
    final snapshot = Map<String, Object?>.from(state.values);
    await state.readGate?.future;
    return {
      for (final entry in snapshot.entries)
        if (allowList == null || allowList.contains(entry.key))
          entry.key: entry.value,
    };
  }

  @override
  Future<void> setString(String key, String value) async {
    if (state.failWrites) throw StateError('Storage unavailable');
    state.values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (state.failWrites) throw StateError('Storage unavailable');
    state.values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RoundResult _round(int day) => RoundResult(
  type: GameType.grid,
  date: DateTime(2026, 10, day),
  duration: const Duration(minutes: 5),
  attempts: const [
    Attempt(
      prompt: '¿Es un reflejo?',
      given: 'Sí',
      expected: 'Sí',
      correct: true,
      skipped: false,
      response: Duration(seconds: 3),
    ),
  ],
);

void main() {
  test(
    'startup merges new rounds and preserves changes made while loading',
    () async {
      final old = _round(18);
      final recent = _round(20);
      final state = _StorageState()
        ..readGate = Completer<void>()
        ..values[_settingsKey] = jsonEncode(const TrainingSettings().toJson())
        ..values[_historyKey] = jsonEncode([old.toJson()]);
      final store = AppStore(preferences: _TestPreferences(state));
      addTearDown(store.dispose);

      final initialization = store.initialize();
      final settingsWrite = store.updateSettings(
        const TrainingSettings(
          roundMinutes: 6,
          difficulty: Difficulty.expert,
          haptics: false,
        ),
      );
      final historyWrite = store.addResults([recent]);
      state.readGate!.complete();
      await Future.wait([initialization, settingsWrite, historyWrite]);

      expect(store.loaded, isTrue);
      expect(store.settings.roundMinutes, 6);
      expect(store.settings.difficulty, Difficulty.expert);
      expect(store.settings.haptics, isFalse);
      expect(store.history.map((round) => round.date.day), [20, 18]);
      final saved = jsonDecode(state.values[_historyKey]! as String) as List;
      expect(saved, hasLength(2));
      expect(
        (jsonDecode(state.values[_settingsKey]! as String)
            as Map)['roundMinutes'],
        6,
      );
    },
  );

  test(
    'clearing during startup cannot restore deleted history or other keys',
    () async {
      final state = _StorageState()
        ..readGate = Completer<void>()
        ..values[_historyKey] = jsonEncode([_round(18).toJson()])
        ..values['unrelated.preference'] = 'keep';
      final store = AppStore(preferences: _TestPreferences(state));
      addTearDown(store.dispose);

      final initialization = store.initialize();
      final clear = store.clearHistory();
      final append = store.addResults([_round(20)]);
      state.readGate!.complete();
      await Future.wait([initialization, clear, append]);

      expect(store.history.map((round) => round.date.day), [20]);
      expect(jsonDecode(state.values[_historyKey]! as String), hasLength(1));
      expect(state.values['unrelated.preference'], 'keep');
    },
  );

  test(
    'failed saves keep results and stay reported until that data is saved',
    () async {
      final state = _StorageState();
      final store = AppStore(preferences: _TestPreferences(state));
      addTearDown(store.dispose);
      await store.initialize();

      state.failWrites = true;
      await store.addResults([_round(18)]);
      expect(store.history, hasLength(1));
      expect(store.storageError, isNotNull);

      state.failWrites = false;
      await store.updateSettings(const TrainingSettings(roundMinutes: 6));
      expect(store.storageError, isNotNull);
      await store.addResults([_round(20)]);
      expect(store.storageError, isNull);
      expect(jsonDecode(state.values[_historyKey]! as String), hasLength(2));
    },
  );

  test(
    'one corrupt entry does not discard the rest of saved history',
    () async {
      final state = _StorageState()
        ..values[_historyKey] = jsonEncode([
          {'broken': true},
          _round(18).toJson(),
        ]);
      final store = AppStore(preferences: _TestPreferences(state));
      addTearDown(store.dispose);

      await store.initialize();
      expect(store.loaded, isTrue);
      expect(store.history, hasLength(1));
      expect(store.history.single.correctCount, 1);
      expect(store.storageError, isNotNull);
    },
  );
}
