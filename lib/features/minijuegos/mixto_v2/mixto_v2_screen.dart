import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../domain/models.dart';
import '../../training/mixed_sequence.dart';
import '../../training/training_screen.dart' show MinijuegoGridChallenge;
import 'mixto_v2_controller.dart';

class MixtoV2Screen extends StatefulWidget {
  const MixtoV2Screen({
    super.key,
    this.onAttempt,
    this.onSessionEnd,
    this.roundDuration = const Duration(minutes: 3),
    this.mode = MixedV2Mode.alternating,
    this.difficulty = Difficulty.advanced,
  });
  final ValueChanged<Attempt>? onAttempt;
  final VoidCallback? onSessionEnd;
  final Duration roundDuration;
  final MixedV2Mode mode;
  final Difficulty difficulty;

  @override
  State<MixtoV2Screen> createState() => _MixtoV2ScreenState();
}

class _MixtoV2ScreenState extends State<MixtoV2Screen>
    with WidgetsBindingObserver {
  late final MixtoV2Controller _controller;
  final ScrollController _scroll = ScrollController();

  void _changed() {
    if (!mounted) return;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MixtoV2Controller(
      mode: widget.mode,
      difficulty: widget.difficulty,
      roundDuration: widget.roundDuration,
      onAttempt: widget.onAttempt,
      onFinished: widget.onSessionEnd,
    )..addListener(_changed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = _controller.question;
    return Column(
      children: [
        ValueListenableBuilder<Duration>(
          valueListenable: _controller.phaseRemaining,
          builder: (context, remaining, _) {
            final duration = _controller.phaseDuration.inMicroseconds;
            final progress = duration == 0
                ? 0.0
                : (remaining.inMicroseconds / duration).clamp(0.0, 1.0);
            return Semantics(
              label: 'Tiempo disponible para este ejercicio',
              child: TweenAnimationBuilder<double>(
                key: ObjectKey(question),
                tween: Tween(begin: progress, end: progress),
                duration: reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 80),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 5,
                  backgroundColor: AppColors.line,
                  color: AppColors.green,
                ),
              ),
            );
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 740),
                child: switch (question) {
                  PointFlashQuestion() => PointFlashView(
                    key: ValueKey(
                      'v2-flash-${_controller.cycle}-${question.index}',
                    ),
                    question: question,
                  ),
                  GridQuestion() => SurfacePanel(
                    child: MinijuegoGridChallenge(
                      key: ObjectKey(question),
                      question: question,
                      onSubmit: (answer) => _controller.answer(
                        answer,
                        expectedQuestion: question,
                      ),
                    ),
                  ),
                  MemorySequenceQuestion() => MemorySequenceRecall(
                    key: ValueKey('v2-recall-${_controller.cycle}'),
                    question: question,
                    onSubmit: (answer) =>
                        _controller.answer(answer, expectedQuestion: question),
                    onSelectionChanged: _controller.setRecallSelection,
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
