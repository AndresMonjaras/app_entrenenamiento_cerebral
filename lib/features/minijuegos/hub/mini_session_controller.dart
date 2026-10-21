import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/models.dart';
import '../common/mini_result.dart';

enum MiniSessionPhase { instructions, playing, complete }

class MiniSessionController extends ChangeNotifier {
  MiniSessionController({
    required List<MiniGame> games,
    this.roundDuration = const Duration(minutes: 5),
    Duration Function()? elapsedNow,
  }) : games = List.unmodifiable(games),
       remaining = ValueNotifier(roundDuration) {
    if (games.isEmpty || roundDuration <= Duration.zero) {
      throw ArgumentError('Selecciona juegos y una duración positiva.');
    }
    _watch.start();
    _now = elapsedNow ?? () => _watch.elapsed;
  }
  final List<MiniGame> games;
  final Duration roundDuration;
  final ValueNotifier<Duration> remaining;
  final Stopwatch _watch = Stopwatch();
  late final Duration Function() _now;
  Timer? _timer;
  var _disposed = false;
  int _index = 0;
  int _question = 0;
  Duration _origin = Duration.zero;
  DateTime? _startedAt;
  final List<Attempt> _attempts = [];
  final List<MiniRoundResult> _rounds = [];
  MiniSessionPhase _phase = MiniSessionPhase.instructions;
  MiniSessionPhase get phase => _phase;
  MiniGame get game => games[_index];
  int get roundIndex => _index;
  int get questionVersion => _question;
  bool get hasProgress =>
      _rounds.isNotEmpty || _phase == MiniSessionPhase.playing;
  Duration get _elapsed {
    final t = _now() - _origin;
    return t.isNegative ? Duration.zero : t;
  }

  void start() {
    if (_disposed || _phase != MiniSessionPhase.instructions) return;
    _origin = _now();
    _startedAt = DateTime.now();
    _attempts.clear();
    _question = 0;
    remaining.value = roundDuration;
    _phase = MiniSessionPhase.playing;
    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => refresh(),
    );
    notifyListeners();
  }

  void refresh() {
    if (_disposed || _phase != MiniSessionPhase.playing) return;
    if (_elapsed >= roundDuration) {
      finishRound();
      return;
    }
    remaining.value = roundDuration - _elapsed;
  }

  void record(Attempt attempt) {
    if (_disposed || _phase != MiniSessionPhase.playing) return;
    if (_elapsed >= roundDuration) {
      finishRound();
      return;
    }
    _attempts.add(attempt);
  }

  void nextSwitchQuestion() {
    if (_disposed ||
        _phase != MiniSessionPhase.playing ||
        game != MiniGame.switchV2) {
      return;
    }
    refresh();
    if (_phase != MiniSessionPhase.playing) return;
    _question++;
    notifyListeners();
  }

  void finishRound() {
    if (_disposed || _phase != MiniSessionPhase.playing) return;
    _timer?.cancel();
    final duration = _elapsed > roundDuration ? roundDuration : _elapsed;
    _rounds.add(
      MiniRoundResult(
        game: game,
        startedAt: _startedAt!,
        duration: duration,
        attempts: _attempts,
      ),
    );
    if (_index + 1 == games.length) {
      _phase = MiniSessionPhase.complete;
    } else {
      _index++;
      _phase = MiniSessionPhase.instructions;
      remaining.value = roundDuration;
    }
    notifyListeners();
  }

  MiniSessionResult get result {
    if (_phase != MiniSessionPhase.complete) {
      throw StateError('La sesión sigue en curso.');
    }
    return MiniSessionResult(date: _rounds.first.startedAt, rounds: _rounds);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watch.stop();
    remaining.dispose();
    super.dispose();
  }
}
