import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../domain/models.dart' show Difficulty, GameType;
import '../common/mini_result.dart';
import 'mini_results_screen.dart';
import 'mini_session_screen.dart';

/// The two remaining Mojarrules modes share the same card layout as the
/// primary practice games. V2 Switch and Mixto stay out of the home menu.
class MojarrulesSection extends StatelessWidget {
  const MojarrulesSection({
    super.key,
    required this.roundDuration,
    required this.difficulty,
  });

  final Duration roundDuration;
  final Difficulty difficulty;

  Future<void> _start(BuildContext context, MiniGame game) async {
    final result = await Navigator.push<MiniSessionResult>(
      context,
      appRoute(
        MiniSessionScreen(
          games: [game],
          roundDuration: roundDuration,
          difficulty: difficulty,
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    await Navigator.push(context, appRoute(MiniResultsScreen(session: result)));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 18.0;
      final columns = constraints.maxWidth >= 620 ? 2 : 1;
      final cardWidth =
          (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final game in MiniGame.practiceModes)
            SizedBox(
              width: cardWidth,
              child: _MiniGameCard(
                game: game,
                ordinal:
                    GameType.practiceModes.length +
                    MiniGame.practiceModes.indexOf(game) +
                    1,
                minutes: roundDuration.inMinutes,
                onStart: () => _start(context, game),
                onInfo: () => _showMiniGameInfo(
                  context,
                  game,
                  () => _start(context, game),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _MiniGameCard extends StatelessWidget {
  const _MiniGameCard({
    required this.game,
    required this.ordinal,
    required this.minutes,
    required this.onStart,
    required this.onInfo,
  });

  final MiniGame game;
  final int ordinal;
  final int minutes;
  final VoidCallback onStart;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final color = _miniGameColor(game);
    return SurfacePanel(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(19),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('mini-card-${game.name}'),
          onTap: onStart,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 117,
                child: Ink(
                  decoration: BoxDecoration(
                    color: _miniGameBackground(game),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(19),
                    ),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ordinal.toString().padLeft(2, '0'),
                              style: TextStyle(
                                color: color.withValues(alpha: .5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 11),
                            Icon(_miniGameIcon(game), color: color, size: 28),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: _MiniGameArt(game: game, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _miniGameSkill(game),
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.title,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -.5,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onInfo,
                          tooltip: 'Cómo jugar ${game.title}',
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.muted,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      game.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 21),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: AppColors.muted,
                                ),
                              ),
                              TextSpan(text: '  $minutes min'),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                        const Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  Icons.bar_chart_rounded,
                                  size: 15,
                                  color: AppColors.muted,
                                ),
                              ),
                              TextSpan(text: '  Alta exigencia'),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onStart,
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                          style: TextButton.styleFrom(foregroundColor: color),
                          label: const Text('Practicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniGameArt extends StatelessWidget {
  const _MiniGameArt({required this.game, required this.color});

  final MiniGame game;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
    child: Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (var index = 0; index < 6; index++)
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: game == MiniGame.chimp
                ? Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Container(
                    width: (7 + index % 3 * 2).toDouble(),
                    height: (7 + index % 3 * 2).toDouble(),
                    decoration: BoxDecoration(
                      color: color.withValues(
                        alpha: index == 1 || index == 4 ? .9 : .25,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
      ],
    ),
  );
}

Color _miniGameColor(MiniGame game) => switch (game) {
  MiniGame.progressive => AppColors.green,
  MiniGame.chimp => AppColors.coral,
  MiniGame.switchV2 => AppColors.amber,
  MiniGame.mixed => const Color(0xFF237A9E),
};

Color _miniGameBackground(MiniGame game) => switch (game) {
  MiniGame.progressive => const Color(0xFFEAF4EE),
  MiniGame.chimp => const Color(0xFFFAEDE7),
  MiniGame.switchV2 => const Color(0xFFFAF1E2),
  MiniGame.mixed => const Color(0xFFE4F2F7),
};

IconData _miniGameIcon(MiniGame game) => switch (game) {
  MiniGame.progressive => Icons.trending_up_rounded,
  MiniGame.chimp => Icons.numbers,
  MiniGame.switchV2 => Icons.alt_route_rounded,
  MiniGame.mixed => Icons.shuffle_rounded,
};

String _miniGameSkill(MiniGame game) => switch (game) {
  MiniGame.progressive => 'MEMORIA Y PROGRESIÓN',
  MiniGame.chimp => 'MEMORIA DE TRABAJO',
  MiniGame.switchV2 => 'LÓGICA Y SECUENCIAS',
  MiniGame.mixed => 'MEMORIA Y RAZONAMIENTO',
};

Future<void> _showMiniGameInfo(
  BuildContext context,
  MiniGame game,
  VoidCallback onStart,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(game.title),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              child: _MiniGameArt(game: game, color: _miniGameColor(game)),
            ),
            const SizedBox(height: 16),
            Text(game.instructions),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
      FilledButton(
        onPressed: () {
          Navigator.pop(context);
          onStart();
        },
        child: const Text('Practicar'),
      ),
    ],
  ),
);
