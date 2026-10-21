import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../../../domain/models.dart';
import '../../../domain/question_generator.dart';
import '../../training/switch_challenge.dart';

/// A one-based position rule, retained for callers of the isolated V2 module.
List<T> applyPerm<T>(List<T> input, List<int> rule) => [
  for (final position in rule) input[position - 1],
];

/// V2 keeps its result callbacks and timer while sharing the reference diagram.
class SwitchChallengeV2Screen extends StatefulWidget {
  const SwitchChallengeV2Screen({
    super.key,
    required this.onResult,
    this.onAttempt,
    this.showTimeBar = true,
    this.timerDuration = const Duration(minutes: 5),
  });

  final void Function(bool correct) onResult;
  final ValueChanged<Attempt>? onAttempt;
  final Duration timerDuration;
  final bool showTimeBar;

  @override
  State<SwitchChallengeV2Screen> createState() =>
      _SwitchChallengeV2ScreenState();
}

class _SwitchChallengeV2ScreenState extends State<SwitchChallengeV2Screen>
    with SingleTickerProviderStateMixin {
  late final SwitchQuestion _question;
  late final AnimationController _timer;
  final Stopwatch _responseWatch = Stopwatch();
  Timer? _delivery;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _question = QuestionGenerator().generate(
      GameType.switcher,
      Difficulty.expert,
    ) as SwitchQuestion;
    _responseWatch.start();
    _timer = AnimationController(vsync: this, duration: widget.timerDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _submit(null);
      })
      ..forward();
  }

  void _submit(int? index) {
    if (_submitted) return;
    _submitted = true;
    _timer.stop();
    _responseWatch.stop();
    if (index != null) HapticFeedback.selectionClick();
    final correct = index != null && _question.check(index);
    widget.onAttempt?.call(
      Attempt(
        prompt: 'Switch V2 · segundo filtro',
        given: index == null ? 'Sin respuesta' : _question.answerLabel(index),
        expected: _question.correctAnswerLabel,
        correct: correct,
        skipped: index == null,
        response: _responseWatch.elapsed,
      ),
    );
    if (!mounted) return;
    // Tactile selection is immediate; scored feedback belongs to the report.
    _delivery = Timer(const Duration(milliseconds: 500), () {
      if (mounted) widget.onResult(correct);
    });
  }

  @override
  void dispose() {
    _delivery?.cancel();
    _responseWatch.stop();
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Column(
        children: [
          if (widget.showTimeBar)
            AnimatedBuilder(
              animation: _timer,
              builder: (context, child) => LinearProgressIndicator(
                value: 1 - _timer.value,
                minHeight: 5,
                backgroundColor: AppColors.line,
                color: AppColors.green,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: AbsorbPointer(
                absorbing: _submitted,
                child: MinijuegoSwitchChallenge(
                  question: _question,
                  onSubmit: (answer) => _submit(answer as int),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
