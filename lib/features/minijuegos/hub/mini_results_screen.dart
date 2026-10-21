import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../results/results_screen.dart' show formatDate;
import '../common/mini_result.dart';

class MiniResultsScreen extends StatelessWidget {
  const MiniResultsScreen({super.key, required this.session});
  final MiniSessionResult session;
  @override
  Widget build(BuildContext context) {
    final attempts = session.attempts;
    final responseMs = attempts.fold<int>(
      0,
      (sum, a) => sum + a.response.inMilliseconds,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Resultados · Los Mojarrules',
          style: TextStyle(fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SmallTag('SESIÓN FINALIZADA'),
                  const SizedBox(height: 18),
                  Text(
                    'Cada ronda cuenta.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatDate(session.date),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  SurfacePanel(
                    color: AppColors.mint,
                    child: Wrap(
                      spacing: 34,
                      runSpacing: 18,
                      children: [
                        _stat(
                          attempts.isEmpty
                              ? '—'
                              : '${(session.accuracy * 100).round()}%',
                          'Precisión global',
                        ),
                        _stat(
                          '${session.correctCount}/${attempts.length}',
                          'Respuestas correctas',
                        ),
                        _stat(
                          attempts.isEmpty
                              ? '—'
                              : '${(responseMs / attempts.length / 1000).toStringAsFixed(1)} s',
                          'Tiempo medio',
                        ),
                        _stat(
                          '${session.duration.inMinutes} min ${session.duration.inSeconds % 60} s',
                          'Tiempo entrenado',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final round in session.rounds) ...[
                    SurfacePanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            round.game.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${round.correctCount} aciertos · ${round.attempts.length - round.correctCount} por mejorar · ${round.attempts.length} respuestas',
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: round.attempts.isEmpty
                                ? 0
                                : round.correctCount / round.attempts.length,
                            minHeight: 6,
                            semanticsLabel: 'Precisión en ${round.game.title}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (round.attempts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No se registraron respuestas en esta ronda.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    for (var i = 0; i < round.attempts.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: ExpansionTile(
                            title: Text(
                              '${i + 1}. ${round.attempts[i].prompt}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              round.attempts[i].correct
                                  ? 'Correcta'
                                  : 'Por mejorar',
                              style: TextStyle(
                                color: round.attempts[i].correct
                                    ? AppColors.green
                                    : AppColors.coral,
                                fontSize: 12,
                              ),
                            ),
                            childrenPadding: const EdgeInsets.all(16),
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Tu respuesta: ${round.attempts[i].given}\nEsperada: ${round.attempts[i].expected}\nTiempo: ${(round.attempts[i].response.inMilliseconds / 1000).toStringAsFixed(1)} s',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                  const Text(
                    'La precisión combina las respuestas registradas de todas las rondas. Los flashes pasivos no cuentan como respuestas. El tiempo de exposición sí forma parte del intento en Memoria y Chimp.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver a los juegos'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => SizedBox(
    width: 145,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}
