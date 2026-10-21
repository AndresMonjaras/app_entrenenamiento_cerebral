import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/mini_result.dart';

/// V2 history has its own key and never replaces the original training history.
class MiniProgressStore extends ChangeNotifier {
  MiniProgressStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  static const storageKey = 'mojarrules.sessions.v1';
  final SharedPreferencesAsync _preferences;
  List<MiniSessionResult> _sessions = [];
  List<MiniSessionResult> get sessions => List.unmodifiable(_sessions);
  String? error;
  bool _disposed = false;
  Future<void>? _initialization;
  Future<void> _writes = Future.value();
  Future<void> initialize() => _initialization ??= _load();
  Future<void> _load() async {
    try {
      final raw = await _preferences.getString(storageKey);
      if (raw != null) {
        for (final entry in jsonDecode(raw) as List) {
          try {
            _sessions.add(
              MiniSessionResult.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ),
            );
          } catch (_) {
            error = 'Una sesión guardada no pudo recuperarse.';
          }
        }
        _sessions.sort((a, b) => b.date.compareTo(a.date));
      }
    } catch (_) {
      error = 'El historial local no está disponible.';
    }
    _notify();
  }

  Future<void> add(MiniSessionResult session) {
    _writes = _writes.then((_) async {
      await initialize();
      _sessions = [session, ..._sessions];
      _notify();
      try {
        await _preferences.setString(
          storageKey,
          jsonEncode(_sessions.map((s) => s.toJson()).toList()),
        );
        error = null;
      } catch (_) {
        error = 'No se pudo guardar. Los resultados se conservan durante esta visita.';
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
