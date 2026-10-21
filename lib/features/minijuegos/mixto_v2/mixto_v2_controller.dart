import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../domain/models.dart';
import '../../../domain/round_controller.dart';

enum MixedV2Mode { alternating, grid, symmetry }

enum MixedV2Phase { reasoning, flash, recall }

/// V2 adapts the same phase deadlines and geometry as the main menu.
class MixtoV2Controller extends ChangeNotifier {
  MixtoV2Controller({
    MixedV2Mode mode = MixedV2Mode.alternating,
    Difficulty difficulty = Difficulty.advanced,
    ValueChanged<Attempt>? onAttempt,
    this.onFinished,
    Duration roundDuration = const Duration(minutes: 3),
    Random? random,
    Duration Function()? elapsedNow,
  }) {
    _round = RoundController(
      switch (mode) {
        MixedV2Mode.alternating => GameType.mixed,
        MixedV2Mode.grid => GameType.grid,
        MixedV2Mode.symmetry => GameType.symmetry,
      },
      TrainingSettings(difficulty: difficulty),
      random: random,
      elapsedNow: elapsedNow,
      durationOverride: roundDuration,
      onAttempt: (attempt) {
        _attempts.add(attempt);
        onAttempt?.call(attempt);
      },
    )..addListener(_changed);
  }
  static const flashDuration = Duration(milliseconds: 3500);
  static const responseDuration = Duration(seconds: 5);
  late final RoundController _round;
  final VoidCallback? onFinished;
  final List<Attempt> _attempts = [];
  bool _reportedFinish = false;
  MixedV2Phase get phase => switch (_round.mixedPhase!) {
    MixedPhase.flash => MixedV2Phase.flash,
    MixedPhase.reasoning => MixedV2Phase.reasoning,
    MixedPhase.recall => MixedV2Phase.recall,
  };
  Question get question => _round.currentQuestion;
  int get sequenceLength => _round.sequenceLength;
  int get sequenceIndex => _round.sequenceIndex;
  int get cycle => _round.mixedCycle;
  GameType get reasoningType => _round.reasoningType;
  bool get isFinished => _round.isFinished;
  Duration get phaseDuration => _round.phaseDuration;
  ValueListenable<Duration> get phaseRemaining => _round.phaseRemaining;
  List<Attempt> get completedAttempts => List.unmodifiable(_attempts);
  void answer(Object answer, {Question? expectedQuestion}) =>
      _round.submit(answer, expectedQuestion: expectedQuestion);
  void refresh() => _round.refresh();
  void setRecallSelection(List<int> selected) =>
      _round.setRecallSelection(selected);
  void _changed() {
    notifyListeners();
    if (_round.isFinished && !_reportedFinish) {
      _reportedFinish = true;
      onFinished?.call();
    }
  }

  @override
  void dispose() {
    _round.dispose();
    super.dispose();
  }
}
