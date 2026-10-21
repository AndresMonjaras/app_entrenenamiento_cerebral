import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'mixed_sequence_controller.dart';
import 'question_generator.dart';

/// Monotonic deadlines own progress; animation completion never advances a game.
class RoundController extends ChangeNotifier {
  RoundController(
    this.type,
    this.settings, {
    Random? random,
    Duration Function()? elapsedNow,
    bool mixedSequences = true,
    this.onAttempt,
    Duration? durationOverride,
  }) : _generator = QuestionGenerator(random: random),
       startedAt = DateTime.now(),
       duration = durationOverride ?? settings.durationFor(type),
       remaining = ValueNotifier(
         durationOverride ?? settings.durationFor(type),
       ),
       phaseRemaining = ValueNotifier(
         durationOverride ?? settings.durationFor(type),
       ) {
    if (duration <= Duration.zero) {
      throw ArgumentError('La duración debe ser positiva.');
    }
    if (elapsedNow == null) {
      _stopwatch.start();
      _elapsedNow = () => _stopwatch.elapsed;
    } else {
      _elapsedNow = elapsedNow;
    }
    _origin = _elapsedNow();
    if (mixedSequences &&
        [
          GameType.memory,
          GameType.grid,
          GameType.symmetry,
          GameType.mixed,
        ].contains(type)) {
      _mixed = MixedSequenceController(
        type: type,
        difficulty: settings.difficulty,
        generator: _generator,
      );
    }
    _currentQuestion =
        _mixed?.currentQuestion ??
        _generator.generate(type, settings.difficulty);
    _memorizing = _currentQuestion is MemoryQuestion;
    _resetPhaseClock();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => refresh());
  }
  final GameType type;
  final TrainingSettings settings;
  final Duration duration;
  final DateTime startedAt;
  final ValueChanged<Attempt>? onAttempt;
  final ValueNotifier<Duration> remaining;
  final ValueNotifier<Duration> phaseRemaining;
  final QuestionGenerator _generator;
  final Stopwatch _stopwatch = Stopwatch();
  MixedSequenceController? _mixed;
  final List<Attempt> _attempts = [];
  late final Duration Function() _elapsedNow;
  late final Duration _origin;
  late Question _currentQuestion;
  Duration _questionStarted = Duration.zero;
  Timer? _timer;
  Timer? _phaseTimer;
  var _questionNumber = 1;
  var _memorizing = false;
  var _finished = false;
  var _disposed = false;
  Duration? _finishedElapsed;
  List<int> _pendingRecall = [];
  Question get currentQuestion => _currentQuestion;
  int get questionNumber => _questionNumber;
  bool get isMemorizing => _memorizing;
  bool get isFinished => _finished;
  bool get isMixed => _mixed != null;
  MixedPhase? get mixedPhase => _mixed?.phase;
  MemorySequenceQuestion? get mixedSequence => _mixed?.memory;
  int get sequenceIndex => _mixed?.index ?? 0;
  int get sequenceLength => _mixed?.memory.sequence.length ?? 0;
  int get mixedCycle => _mixed?.cycleNumber ?? 0;
  GameType get reasoningType => _mixed?.reasoningType ?? type;
  int? get flashCell => mixedPhase == MixedPhase.flash
      ? _mixed!.memory.sequence[_mixed!.index]
      : null;
  Duration get flashDuration => _mixed?.flashDuration ?? Duration.zero;
  Duration get phaseDuration => _mixed?.phaseDuration ?? duration;
  Duration get flashRemaining => mixedPhase == MixedPhase.flash && !_finished
      ? _leftInPhase
      : Duration.zero;
  Duration get _elapsed {
    final raw = _elapsedNow() - _origin;
    return raw.isNegative ? Duration.zero : raw;
  }

  Duration get _leftInPhase {
    final left = phaseDuration - (_elapsed - _questionStarted);
    return left.isNegative ? Duration.zero : left;
  }

  Duration get previewRemaining {
    if (!_memorizing || _finished) return Duration.zero;
    final left =
        Duration(
          milliseconds:
              (_currentQuestion as MemoryQuestion).previewMilliseconds,
        ) -
        (_elapsed - _questionStarted);
    return left.isNegative ? Duration.zero : left;
  }

  List<Attempt> get attempts {
    if (!_finished) throw StateError('La ronda todavía está en curso.');
    return List.unmodifiable(_attempts);
  }

  void _resetPhaseClock() {
    _phaseTimer?.cancel();
    _pendingRecall = [];
    phaseRemaining.value = phaseDuration;
    if (_mixed != null) _phaseTimer = Timer(phaseDuration, refresh);
  }

  void refresh() {
    if (_disposed || _finished) return;
    final elapsed = _elapsed;
    if (elapsed >= duration) {
      _complete(duration);
      return;
    }
    remaining.value = duration - elapsed;
    if (_mixed != null) {
      final left = phaseDuration - (elapsed - _questionStarted);
      phaseRemaining.value = left.isNegative ? Duration.zero : left;
      if (left <= Duration.zero) {
        _expirePhase();
      } else if (!(_phaseTimer?.isActive ?? false)) {
        _phaseTimer = Timer(left, refresh);
      }
    } else if (_memorizing && previewRemaining == Duration.zero) {
      _memorizing = false;
      notifyListeners();
    }
  }

  void _expirePhase() {
    if (_mixed!.phase == MixedPhase.flash) {
      _mixed!.finishFlash();
    } else {
      final recall = _currentQuestion is MemorySequenceQuestion;
      final complete =
          recall &&
          _pendingRecall.length ==
              (_currentQuestion as MemorySequenceQuestion).sequence.length;
      _append(
        recall ? List<int>.of(_pendingRecall) : null,
        skipped: !complete,
        response: phaseDuration,
      );
      if (_disposed || _finished) return;
      _mixed!.answer();
    }
    _useMixedQuestion();
  }

  void setRecallSelection(List<int> selected) {
    if (_disposed || _finished || _currentQuestion is! MemorySequenceQuestion) {
      return;
    }
    final before = _currentQuestion;
    refresh();
    if (_disposed || _finished || !identical(before, _currentQuestion)) return;
    _pendingRecall = List.of(selected);
  }

  void submit(Object? answer, {Question? expectedQuestion}) {
    if (_disposed ||
        _finished ||
        (expectedQuestion != null &&
            !identical(expectedQuestion, _currentQuestion))) {
      return;
    }
    final before = _currentQuestion;
    final wasFlash = mixedPhase == MixedPhase.flash;
    refresh();
    if (_finished ||
        _memorizing ||
        wasFlash ||
        !identical(before, _currentQuestion)) {
      return;
    }
    if (_mixed != null &&
        ((_currentQuestion is MemorySequenceQuestion && answer is! List<int>) ||
            (_currentQuestion is GridQuestion && answer is! bool))) {
      return;
    }
    if (_record(answer, skipped: false)) _nextQuestion();
  }

  void skip() {
    if (_disposed || _finished) return;
    final before = _currentQuestion;
    final wasFlash = mixedPhase == MixedPhase.flash;
    refresh();
    if (_finished || wasFlash || !identical(before, _currentQuestion)) return;
    if (_record(null, skipped: true)) _nextQuestion();
  }

  bool _record(Object? answer, {required bool skipped}) {
    final elapsed = _elapsed;
    if (elapsed >= duration) {
      _complete(duration);
      return false;
    }
    if (_mixed != null && elapsed - _questionStarted >= phaseDuration) {
      _expirePhase();
      return false;
    }
    _append(answer, skipped: skipped, response: elapsed - _questionStarted);
    return !_disposed && !_finished;
  }

  void _append(
    Object? answer, {
    required bool skipped,
    required Duration response,
  }) {
    final hasPartial = answer is List<int> && answer.isNotEmpty;
    final attempt = Attempt(
      prompt: _currentQuestion.prompt,
      given: skipped && !hasPartial
          ? 'Omitida'
          : _currentQuestion.answerLabel(answer),
      expected: _currentQuestion.correctAnswerLabel,
      correct: !skipped && _currentQuestion.check(answer),
      skipped: skipped,
      response: response.isNegative ? Duration.zero : response,
    );
    _attempts.add(attempt);
    onAttempt?.call(attempt);
  }

  void _nextQuestion() {
    if (_mixed != null) {
      _mixed!.answer();
      _useMixedQuestion();
      return;
    }
    _questionNumber++;
    _currentQuestion = _generator.generate(
      type,
      settings.difficulty,
      questionNumber: _questionNumber,
    );
    _questionStarted = _elapsed;
    _memorizing = _currentQuestion is MemoryQuestion;
    notifyListeners();
  }

  void _useMixedQuestion() {
    _questionNumber++;
    _currentQuestion = _mixed!.currentQuestion;
    _questionStarted = _elapsed;
    _memorizing = false;
    _resetPhaseClock();
    notifyListeners();
  }

  void finish() {
    if (_disposed || _finished) return;
    final elapsed = _elapsed;
    _complete(elapsed > duration ? duration : elapsed);
  }

  void _complete(Duration elapsed) {
    if (_finished) return;
    _finished = true;
    _memorizing = false;
    _finishedElapsed = elapsed;
    _timer?.cancel();
    _phaseTimer?.cancel();
    _stopwatch.stop();
    remaining.value = duration - elapsed;
    phaseRemaining.value = Duration.zero;
    notifyListeners();
  }

  RoundResult get result {
    if (!_finished) throw StateError('La ronda todavía está en curso.');
    return RoundResult(
      type: type,
      date: startedAt,
      duration: _finishedElapsed!,
      attempts: _attempts,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _phaseTimer?.cancel();
    _stopwatch.stop();
    remaining.dispose();
    phaseRemaining.dispose();
    super.dispose();
  }
}
