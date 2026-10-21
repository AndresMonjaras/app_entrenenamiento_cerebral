import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../domain/models.dart' show Difficulty;
import '../../results/results_screen.dart' show formatDate;
import '../common/mini_result.dart';
import 'mini_progress_store.dart';
import 'mini_results_screen.dart';
import 'mini_session_screen.dart';

/// The Mojarrules games live in the main practice list, alongside the other
/// game cards. This section owns their separate V2 history and sessions.
class MojarrulesSection extends StatefulWidget {
  const MojarrulesSection({
    super.key,
    required this.roundDuration,
    required this.difficulty,
    this.store,
  });

  final Duration roundDuration;
  final Difficulty difficulty;
  final MiniProgressStore? store;

  @override
  State<MojarrulesSection> createState() => _MojarrulesSectionState();
}

class _MojarrulesSectionState extends State<MojarrulesSection> {
  late final MiniProgressStore _store = widget.store ?? MiniProgressStore();

  @override
  void initState() {
    super.initState();
    _store.initialize();
  }

  @override
  void dispose() {
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  Future<void> _start(List<MiniGame> games) async {
    final result = await Navigator.push<MiniSessionResult>(
      context,
      appRoute(
        MiniSessionScreen(
          games: games,
          roundDuration: widget.roundDuration,
          difficulty: widget.difficulty,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _store.add(result);
    if (mounted) {
      await Navigator.push(
        context,
        appRoute(MiniResultsScreen(session: result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'LOS MOJARRULES · V2',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.muted,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Una mojarra, cuatro retos.',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 5),
      const Text(
        'Practica cada modo o juega el test completo. Los resultados se guardan en un historial propio.',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 18),
      SurfacePanel(
        color: AppColors.mint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test completo V2',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Switch V2 → Memoria progresiva → Chimp Test → Mixto V2. Hasta ${widget.roundDuration.inMinutes} minutos por modo; cada uno espera que aceptes sus instrucciones.',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('v2-full-test'),
              onPressed: () => _start(MiniGame.values),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Empezar test V2'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 16.0;
          final columns = constraints.maxWidth >= 620 ? 2 : 1;
          final cardWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final game in MiniGame.values)
                SizedBox(
                  width: cardWidth,
                  child: _MiniGameCard(game: game, onTap: () => _start([game])),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 24),
      Text(
        'Historial de Los Mojarrules',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 14),
      AnimatedBuilder(
        animation: _store,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_store.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _store.error!,
                  style: const TextStyle(color: AppColors.coral),
                ),
              ),
            if (_store.sessions.isEmpty)
              const SurfacePanel(
                child: Text(
                  'Completa tu primera sesión. Aquí quedarán tus resultados acumulados.',
                ),
              ),
            for (final session in _store.sessions)
              Card(
                child: ListTile(
                  title: Text(
                    '${session.rounds.length} rondas · ${session.attempts.length} respuestas',
                  ),
                  subtitle: Text(formatDate(session.date)),
                  trailing: Text('${(session.accuracy * 100).round()}%'),
                  onTap: () => Navigator.push(
                    context,
                    appRoute(MiniResultsScreen(session: session)),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _MiniGameCard extends StatelessWidget {
  const _MiniGameCard({required this.game, required this.onTap});

  final MiniGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.line),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('v2-card-${game.name}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              switch (game) {
                MiniGame.switchV2 => Icons.alt_route_rounded,
                MiniGame.progressive => Icons.trending_up,
                MiniGame.chimp => Icons.numbers,
                MiniGame.mixed => Icons.shuffle_rounded,
              },
              color: AppColors.green,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    game.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
