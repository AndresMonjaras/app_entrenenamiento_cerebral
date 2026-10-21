import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

/// Local source of truth for practice settings and completed rounds.
/// Optimistic updates keep training usable if platform storage is unavailable.
class AppStore extends ChangeNotifier {
  AppStore({SharedPreferencesAsync? preferences}) : _storage = preferences;

  static const _settingsKey = 'pg_prep.settings.v1';
  static const _historyKey = 'pg_prep.history.v1';

  SharedPreferencesAsync? _storage;
  SharedPreferencesAsync get _preferences =>
      _storage ??= SharedPreferencesAsync();
  TrainingSettings _settings = const TrainingSettings();
  List<RoundResult> _history = [];
  bool _loaded = false;
  bool _disposed = false;
  bool _settingsChangedBeforeLoad = false;
  bool _historyClearedBeforeLoad = false;
  final List<RoundResult> _resultsBeforeLoad = [];
  final Set<String> _failedWriteKeys = {};
  String? _storageError;
  Future<void>? _initialization;
  Future<void> _writes = Future<void>.value();

  TrainingSettings get settings => _settings;
  List<RoundResult> get history => List.unmodifiable(_history);
  bool get loaded => _loaded;
  String? get storageError => _storageError;

  Future<void> initialize() => _initialization ??= _load();

  Future<void> _load() async {
    final restoredHistory = <RoundResult>[];
    try {
      final values = await _preferences.getAll(
        allowList: {_settingsKey, _historyKey},
      );
      final settingsData = values[_settingsKey];
      if (settingsData is String && !_settingsChangedBeforeLoad) {
        try {
          _settings = TrainingSettings.fromJson(
            Map<String, dynamic>.from(jsonDecode(settingsData) as Map),
          );
        } catch (_) {
          _storageError = 'Se restauró la configuración predeterminada.';
        }
      }
      final historyData = values[_historyKey];
      if (historyData is String) {
        try {
          final entries = jsonDecode(historyData) as List<dynamic>;
          for (final entry in entries) {
            try {
              restoredHistory.add(
                RoundResult.fromJson(Map<String, dynamic>.from(entry as Map)),
              );
            } catch (_) {
              _storageError = 'Una ronda guardada no se pudo recuperar.';
            }
          }
        } catch (_) {
          _storageError = 'El historial guardado no se pudo recuperar.';
        }
      }
    } catch (_) {
      _storageError = 'El almacenamiento local no está disponible. Puedes seguir entrenando.';
    } finally {
      _history = [
        if (!_historyClearedBeforeLoad) ...restoredHistory,
        ..._resultsBeforeLoad,
      ]..sort((a, b) => b.date.compareTo(a.date));
      _resultsBeforeLoad.clear();
      _loaded = true;
      _notify();
    }
  }

  Future<void> updateSettings(TrainingSettings settings) {
    if (!_loaded) _settingsChangedBeforeLoad = true;
    _settings = settings;
    final encoded = jsonEncode(settings.toJson());
    _notify();
    return _enqueue(
      _settingsKey,
      () => _preferences.setString(_settingsKey, encoded),
    );
  }

  Future<void> addResults(List<RoundResult> results) {
    if (results.isEmpty) return Future<void>.value();
    if (!_loaded) _resultsBeforeLoad.addAll(results);
    _history = [...results, ..._history]
      ..sort((a, b) => b.date.compareTo(a.date));
    _notify();
    return _enqueue(
      _historyKey,
      () => _preferences.setString(
        _historyKey,
        jsonEncode(_history.map((result) => result.toJson()).toList()),
      ),
    );
  }

  Future<void> clearHistory() {
    if (!_loaded) {
      _historyClearedBeforeLoad = true;
      _resultsBeforeLoad.clear();
    }
    _history = [];
    _notify();
    return _enqueue(_historyKey, () => _preferences.remove(_historyKey));
  }

  Future<void> _enqueue(String key, Future<void> Function() write) {
    // Sequential writes prevent a slow older save from replacing newer results.
    _writes = _writes.then((_) async {
      // Loading completes first, so a save cannot erase unmerged older rounds.
      await initialize();
      try {
        await write();
        _failedWriteKeys.remove(key);
        if (_failedWriteKeys.isEmpty) _storageError = null;
      } catch (_) {
        _failedWriteKeys.add(key);
        _storageError = 'No se pudieron guardar los cambios. Se conservan durante esta sesión.';
      }
      _notify();
    });
    return _writes;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
