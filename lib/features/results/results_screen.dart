import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../home/game_art.dart';

String formatDate(DateTime date) {
  final local = date.toLocal();
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.green),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.results});
  final List<RoundResult> results;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final attempts = widget.results.expand((r) => r.attempts).toList();
    final correct = attempts.where((a) => a.correct).length;
    final skipped = attempts.where((a) => a.skipped).length;
    final accuracy = attempts.isEmpty ? 0.0 : correct / attempts.length;
    final average = attempts.isEmpty
        ? 0.0
        : attempts.fold<int>(0, (s, a) => s + a.response.inMilliseconds) /
              attempts.length /
              1000;
    final duration = widget.results.fold<int>(
      0,
      (s, r) => s + r.duration.inSeconds,
    );
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Tu reporte de entrenamiento',
          style: TextStyle(fontSize: 15),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(narrow ? 20 : 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SmallTag('SESIÓN FINALIZADA'),
                  const SizedBox(height: 16),
                  Text(
                    'Así fue tu entrenamiento.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${widget.results.length} ${widget.results.length == 1 ? 'ronda' : 'rondas'} · ${duration ~/ 60} min ${duration % 60} s de práctica',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 28),
                  SurfacePanel(
                    color: AppColors.mint,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final chart = Semantics(
                          label:
                              'Precisión: ${(accuracy * 100).round()} por ciento',
                          child: SizedBox(
                            width: 160,
                            height: 160,
                            child: CustomPaint(
                              painter: _AccuracyPainter(accuracy),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      attempts.isEmpty
                                          ? '—'
                                          : '${(accuracy * 100).round()}%',
                                      style: const TextStyle(
                                        fontSize: 38,
                                        letterSpacing: -1.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.green,
                                      ),
                                    ),
                                    const Text(
                                      'precisión',
                                      style: TextStyle(
                                        color: AppColors.green,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                        final text = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attempts.isEmpty
                                  ? 'El siguiente intento te espera.'
                                  : accuracy >= .8
                                  ? 'Precisión que se nota.'
                                  : accuracy >= .5
                                  ? 'Ya tienes una base para crecer.'
                                  : 'Cada reto te enseña algo.',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              attempts.isEmpty
                                  ? 'No registraste respuestas en esta ronda. Empieza una nueva sesión para conocer tu desempeño.'
                                  : 'Respondiste ${attempts.length} ejercicios y acertaste $correct. Usa este reporte para ajustar tu estrategia en la próxima sesión.',
                              style: const TextStyle(color: Color(0xFF507969)),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Resultados de práctica. No representan una puntuación oficial ni una predicción de selección.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF507969),
                              ),
                            ),
                          ],
                        );
                        return constraints.maxWidth < 530
                            ? Column(
                                children: [
                                  chart,
                                  const SizedBox(height: 24),
                                  text,
                                ],
                              )
                            : Row(
                                children: [
                                  chart,
                                  const SizedBox(width: 36),
                                  Expanded(child: text),
                                ],
                              );
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final stat in [
                          (
                            '${attempts.length}',
                            'Ejercicios registrados',
                            Icons.touch_app_outlined,
                          ),
                          (
                            attempts.isEmpty
                                ? '—'
                                : '${average.toStringAsFixed(1)} s',
                            'Tiempo medio por ejercicio',
                            Icons.timer_outlined,
                          ),
                          (
                            '$skipped',
                            'Ejercicios omitidos',
                            Icons.skip_next_outlined,
                          ),
                        ])
                          SizedBox(
                            width: constraints.maxWidth >= 650
                                ? (constraints.maxWidth - 24) / 3
                                : constraints.maxWidth,
                            child: SurfacePanel(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Icon(
                                    stat.$3,
                                    color: AppColors.green,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stat.$1,
                                          style: const TextStyle(
                                            fontSize: 25,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          stat.$2,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Tu desempeño por habilidad',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  SurfacePanel(
                    child: Column(
                      children: [
                        for (var i = 0; i < widget.results.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Divider(),
                            ),
                          _RoundBreakdown(result: widget.results[i]),
                        ],
                      ],
                    ),
                  ),
                  if (attempts.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    SurfacePanel(
                      color: const Color(0xFFFAF4E8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            color: AppColors.amber,
                            size: 23,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Para tu próxima sesión',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _recommendation(widget.results),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  Text(
                    'Revisa tus respuestas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El tiempo medio incluye los ejercicios omitidos. Los flashes intercalados no se cuentan como respuestas.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < 3; i++)
                        ChoiceChip(
                          label: Text(['Todas', 'Por mejorar', 'Correctas'][i]),
                          selected: _filter == i,
                          onSelected: (_) => setState(() => _filter = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final round in widget.results) ...[
                    if (round.attempts.where(_visible).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          round.type.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    for (var i = 0; i < round.attempts.length; i++)
                      if (_visible(round.attempts[i]))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AttemptTile(
                            attempt: round.attempts[i],
                            number: i + 1,
                          ),
                        ),
                  ],
                  if (!attempts.any(_visible))
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No hay respuestas en este filtro.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Volver a mi espacio'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _visible(Attempt a) => switch (_filter) {
    1 => !a.correct,
    2 => a.correct,
    _ => true,
  };
}

String _recommendation(List<RoundResult> results) {
  final completed = results.where((r) => r.attempts.isNotEmpty).toList()
    ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
  if (completed.isEmpty) {
    return 'Completa una ronda para descubrir qué habilidad puedes trabajar.';
  }
  return switch (completed.first.type) {
    GameType.memory => 'En memoria, agrupa las posiciones en pequeñas figuras y usa las esquinas como anclas. Confirma el patrón completo antes de responder.',
    GameType.grid => 'Usa una celda de referencia para resolver las cuadrículas. Después de cada pregunta, conserva el orden del punto que parpadea hasta llegar a la recuperación final.',
    GameType.symmetry => 'Distingue identidad de reflejo según la consigna. Asocia cada punto intercalado a su turno: primero, segundo y así hasta reconstruir la secuencia.',
    GameType.switcher => 'En secuencias, resuelve primero la regla superior. Después sigue una sola figura a través de cada opción para descartar más rápido.',
    GameType.mixed => 'Asocia cada punto con su turno. Al alternar Grid y Simetría, conserva el orden y revisa los errores cuando termine la sesión.',
    GameType.strokes => 'Revisa extremos, intersecciones y diagonales. Cada trazo de los dos paneles debe estar presente, y no puede aparecer ninguna línea adicional.',
    GameType.math => 'En cálculo, identifica primero los términos con × y ÷. Comprueba el objetivo antes de confirmar y utiliza cada ficha una sola vez.',
  };
}

class _RoundBreakdown extends StatelessWidget {
  const _RoundBreakdown({required this.result});
  final RoundResult result;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Icon(gameIcon(result.type), color: gameColor(result.type), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              result.type.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${result.correctCount}/${result.attempts.length}',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Text(
            '${(result.accuracy * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      const SizedBox(height: 14),
      LinearProgressIndicator(
        value: result.accuracy,
        minHeight: 7,
        color: gameColor(result.type),
        backgroundColor: gameBackground(result.type),
        borderRadius: BorderRadius.circular(5),
        semanticsLabel: 'Precisión en ${result.type.title}',
        semanticsValue: '${(result.accuracy * 100).round()}%',
      ),
    ],
  );
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({required this.attempt, required this.number});
  final Attempt attempt;
  final int number;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.line),
      borderRadius: BorderRadius.circular(13),
    ),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(
        attempt.correct
            ? Icons.check_circle_outline_rounded
            : attempt.skipped
            ? Icons.skip_next_rounded
            : Icons.remove_circle_outline_rounded,
        color: attempt.correct ? AppColors.green : AppColors.coral,
        size: 22,
      ),
      title: Text(
        '$number. ${attempt.prompt}',
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        '${attempt.skipped
            ? 'Omitida'
            : attempt.correct
            ? 'Correcta'
            : 'Por mejorar'} · ${(attempt.response.inMilliseconds / 1000).toStringAsFixed(1)} s',
        style: const TextStyle(color: AppColors.muted, fontSize: 11),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu respuesta: ${attempt.given}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                'Respuesta esperada: ${attempt.expected}',
                style: const TextStyle(color: AppColors.green, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AccuracyPainter extends CustomPainter {
  _AccuracyPainter(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = AppColors.green.withValues(alpha: .12);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, paint);
    paint.color = AppColors.green;
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, paint);
    }
  }

  @override
  bool shouldRepaint(_AccuracyPainter oldDelegate) =>
      oldDelegate.value != value;
}
