import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../domain/models.dart';
import '../../training/switch_challenge.dart' show SwitchWalkthrough;
import '../../training/mixed_walkthrough.dart' show MixedSequenceWalkthrough;
import '../common/mini_result.dart';
import '../memoria_progresiva/chimp_test_screen.dart';
import '../memoria_progresiva/memoria_progresiva_screen.dart';
import '../mixto_v2/mixto_v2_screen.dart';
import '../switch_challenge_v2/switch_challenge_v2_screen.dart';
import 'mini_session_controller.dart';
import 'number_memory_walkthrough.dart';

class MiniSessionScreen extends StatefulWidget {
  const MiniSessionScreen({
    super.key,
    required this.games,
    this.roundDuration = const Duration(minutes: 5),
    this.difficulty = Difficulty.advanced,
  });
  final List<MiniGame> games;
  final Duration roundDuration;
  final Difficulty difficulty;
  @override
  State<MiniSessionScreen> createState() => _MiniSessionScreenState();
}

class _MiniSessionScreenState extends State<MiniSessionScreen>
    with WidgetsBindingObserver {
  late final MiniSessionController _controller;
  bool _allowPop = false;
  bool _dialogOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MiniSessionController(
      games: widget.games,
      roundDuration: widget.roundDuration,
    )..addListener(_changed);
  }

  void _changed() {
    if (!mounted || _allowPop) return;
    if (_dialogOpen && _controller.phase != MiniSessionPhase.playing) {
      // A deadline can pass while a confirmation is open. Close that route
      // before returning the typed session result to the main screen.
      _dialogOpen = false;
      if (ModalRoute.of(context)?.isCurrent == false) {
        Navigator.pop(context, false);
      }
    }
    setState(() {});
    if (_controller.phase == MiniSessionPhase.complete) {
      _allowPop = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, _controller.result);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.refresh();
  }

  Future<void> _exit() async {
    if (!_controller.hasProgress) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    if (_dialogOpen) return;
    _dialogOpen = true;
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir del test?'),
        content: const Text(
          'Se descartará la sesión en curso. Para conservar una ronda, usa Terminar ronda y completa el recorrido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted || exit != true) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _finish() async {
    if (_dialogOpen || _controller.phase != MiniSessionPhase.playing) return;
    _dialogOpen = true;
    final finish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Terminar esta ronda?'),
        content: const Text(
          'Se conservarán las respuestas registradas. Los aciertos y errores se mostrarán en el reporte final.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminar ronda'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (mounted && finish == true) _controller.finishRound();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _controller.phase == MiniSessionPhase.playing;
    return PopScope<MiniSessionResult>(
      canPop: _allowPop || !_controller.hasProgress,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Salir de Los Mojarrules',
            onPressed: _exit,
            icon: const Icon(Icons.arrow_back),
          ),
          title: playing
              ? null
              : Text(
                  _controller.game.title,
                  style: const TextStyle(fontSize: 16),
                ),
          actions: [
            if (playing)
              IconButton(
                onPressed: _finish,
                tooltip: 'Terminar ronda',
                icon: const Icon(Icons.stop_circle_outlined),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (!playing)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ronda ${_controller.roundIndex + 1} de ${widget.games.length}',
                        ),
                      ),
                      const SmallTag('INSTRUCCIONES'),
                    ],
                  ),
                ),
              if (playing && _controller.game != MiniGame.mixed)
                ValueListenableBuilder<Duration>(
                  valueListenable: _controller.remaining,
                  builder: (_, remaining, _) => LinearProgressIndicator(
                    value:
                        (remaining.inMicroseconds /
                                widget.roundDuration.inMicroseconds)
                            .clamp(0, 1),
                    minHeight: 5,
                    semanticsLabel: 'Tiempo restante de ronda',
                  ),
                ),
              Expanded(child: playing ? _game() : _instructions()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _instructions() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              _controller.game.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(_controller.game.instructions),
            const SizedBox(height: 24),
            switch (_controller.game) {
              MiniGame.switchV2 => const SwitchWalkthrough(),
              MiniGame.mixed => const MixedSequenceWalkthrough(
                type: GameType.mixed,
              ),
              MiniGame.progressive => const NumberMemoryWalkthrough(
                chimp: false,
              ),
              MiniGame.chimp => const NumberMemoryWalkthrough(chimp: true),
            },
            const SizedBox(height: 20),
            SmallTag(
              'Máximo ${widget.roundDuration.inMinutes} min · resultados al final',
            ),
            const SizedBox(height: 12),
            const Text(
              'El reloj comienza al aceptar. Sigue contando si sales temporalmente de la app.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _controller.start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Entendido, empezar'),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _game() => switch (_controller.game) {
    MiniGame.switchV2 => SwitchChallengeV2Screen(
      key: ValueKey('switch-v2-${_controller.questionVersion}'),
      timerDuration: _controller.remaining.value,
      showTimeBar: false,
      onAttempt: _controller.record,
      onResult: (_) => _controller.nextSwitchQuestion(),
    ),
    MiniGame.progressive => MemoriaProgresivaScreen(
      key: const ValueKey('progressive-session'),
      onAttempt: _controller.record,
      onSessionEnd: _controller.finishRound,
      deferredFeedback: true,
    ),
    MiniGame.chimp => ChimpTestScreen(
      key: const ValueKey('chimp-session'),
      onAttempt: _controller.record,
      onSessionEnd: (_) => _controller.finishRound(),
    ),
    MiniGame.mixed => MixtoV2Screen(
      key: const ValueKey('mixed-v2-session'),
      difficulty: widget.difficulty,
      roundDuration: widget.roundDuration,
      onSessionEnd: _controller.finishRound,
      onAttempt: _controller.record,
    ),
  };
}
