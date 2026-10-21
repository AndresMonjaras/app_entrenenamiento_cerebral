import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import 'scattered_dot_board.dart';

/// An unscored preview of a complete cycle, including its final reasoning task.
class MixedSequenceWalkthrough extends StatefulWidget {
  const MixedSequenceWalkthrough({super.key, required this.type});
  final GameType type;

  @override
  State<MixedSequenceWalkthrough> createState() =>
      _MixedSequenceWalkthroughState();
}

class _MixedSequenceWalkthroughState extends State<MixedSequenceWalkthrough>
    with SingleTickerProviderStateMixin {
  static final _example = MemorySequenceQuestion(
    templateCells: List.generate(24, (index) => index),
    sequence: [2, 18, 11],
    positions: const {
      0: math.Point(.08, .12),
      1: math.Point(.29, .08),
      2: math.Point(.15, .30),
      3: math.Point(.46, .16),
      4: math.Point(.68, .10),
      5: math.Point(.89, .19),
      6: math.Point(.05, .49),
      7: math.Point(.34, .34),
      8: math.Point(.54, .33),
      9: math.Point(.78, .32),
      10: math.Point(.97, .43),
      11: math.Point(.63, .57),
      12: math.Point(.23, .53),
      13: math.Point(.43, .56),
      14: math.Point(.83, .56),
      15: math.Point(.08, .74),
      16: math.Point(.34, .79),
      17: math.Point(.55, .81),
      18: math.Point(.94, .76),
      19: math.Point(.72, .91),
      20: math.Point(.18, .95),
      21: math.Point(.43, .98),
      22: math.Point(.96, .97),
      23: math.Point(.025, .97),
    },
  );
  bool get _memoryOnly => widget.type == GameType.memory;
  int get _durationMs => _memoryOnly ? 15500 : 30500;
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _durationMs),
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _motion.stop();
      _motion.value = .97;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MixedSequenceWalkthrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _motion.duration = Duration(milliseconds: _durationMs);
      if (!reduceMotion(context)) _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.type == GameType.symmetry
        ? const Color(0xFF4B82A1)
        : AppColors.purple;
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final elapsed = _motion.value * _durationMs;
        final pair = _memoryOnly
            ? (elapsed / 3500).floor().clamp(0, 2)
            : (elapsed / 8500).floor().clamp(0, 2);
        final recallStart = _memoryOnly ? 10500 : 25500;
        final recall = elapsed >= recallStart;
        final pairStart = pair * (_memoryOnly ? 3500 : 8500);
        final flash = !recall && elapsed - pairStart < 3500;
        final phase = recall ? 6 : pair * 2 + (flash ? 0 : 1);
        final selectedCount = recall
            ? ((elapsed - recallStart + 300) / 1000).floor().clamp(0, 3)
            : 0;
        final reasoningType = widget.type == GameType.mixed
            ? pair.isOdd
                  ? GameType.symmetry
                  : GameType.grid
            : widget.type;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.play_circle_outline_rounded, color: color, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'EJEMPLO DE SECUENCIA',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Semantics(
              image: true,
              label: _memoryOnly
                  ? 'Ejemplo: memoriza tres puntos numerados en orden. Al final selecciona las mismas posiciones del uno al tres.'
                  : 'Ejemplo: punto uno, figura, punto dos, figura, punto tres, figura. Al final selecciona las posiciones del uno al tres.',
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 270,
                  child: Center(
                    child: flash || recall
                        ? ScatteredDotBoard(
                            question: _example,
                            selected: _example.sequence
                                .take(selectedCount)
                                .toList(),
                            onSelect: recall ? (_) {} : null,
                            enabled: false,
                            flashCell: flash ? _example.sequence[pair] : null,
                            flashNumber: flash ? pair + 1 : null,
                            animation: AlwaysStoppedAnimation(
                              (elapsed - pairStart) / 3500,
                            ),
                            reducedMotion: reduceMotion(context),
                          )
                        : RepaintBoundary(
                            child: CustomPaint(
                              size: const Size(340, 260),
                              painter: _ReasoningDemoPainter(
                                reasoningType,
                                pair,
                                color,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              recall
                  ? 'Marca 1 → 2 → 3 en las posiciones que recuerdas'
                  : flash
                  ? 'Recuerda el punto ${pair + 1}'
                  : reasoningType == GameType.symmetry
                  ? 'Resuelve Simetría e identidad'
                  : 'Resuelve Grid Challenge',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 5,
              runSpacing: 7,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < 7; i++)
                  if (!_memoryOnly || i.isEven)
                    SmallTag(
                      const [
                        'Punto 1',
                        'Figura',
                        'Punto 2',
                        'Figura',
                        'Punto 3',
                        'Figura',
                        'Orden',
                      ][i],
                      color: phase == i ? Colors.white : AppColors.muted,
                      background: phase == i ? color : AppColors.background,
                    ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _memoryOnly
                  ? '3.5 s por punto · Desvanecimientos de 0.5 s · 5 s para marcar el orden'
                  : '3.5 s por punto · Desvanecimientos de 0.5 s · 5 s por figura · 5 s para marcar el orden',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        );
      },
    );
  }
}

class _ReasoningDemoPainter extends CustomPainter {
  const _ReasoningDemoPainter(this.type, this.index, this.color);
  final GameType type;
  final int index;
  final Color color;

  void _text(
    Canvas canvas,
    String label,
    Offset center, {
    Color color = AppColors.ink,
    double size = 12,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'FiraSans',
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 340, size.height / 260);
    canvas.save();
    canvas.translate(
      (size.width - 340 * scale) / 2,
      (size.height - 260 * scale) / 2,
    );
    canvas.scale(scale);
    final cells = <int>{0, 1, 2, 5, 10, 15, 20, 21};
    final identity = type == GameType.symmetry && index.isOdd;
    final other = cells.map((cell) {
      final r = cell ~/ 5, c = cell % 5;
      if (type == GameType.symmetry) return identity ? cell : r * 5 + (4 - c);
      return c * 5 + 4 - r;
    }).toSet();
    for (var panel = 0; panel < 2; panel++) {
      final origin = Offset(panel == 0 ? 35 : 197, 50);
      final active = panel == 0 ? cells : other;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          origin & const Size.square(108),
          const Radius.circular(12),
        ),
        Paint()..color = AppColors.ink,
      );
      for (var i = 0; i < 25; i++) {
        final center = origin + Offset(12 + i % 5 * 21.0, 12 + i ~/ 5 * 21.0);
        if (active.contains(i)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: center, width: 13, height: 13),
              const Radius.circular(3),
            ),
            Paint()..color = AppColors.mint,
          );
        } else {
          canvas.drawCircle(
            center,
            1.8,
            Paint()..color = Colors.white.withValues(alpha: .3),
          );
        }
      }
    }
    _text(
      canvas,
      type == GameType.symmetry ? (identity ? '=' : '↔') : '↻',
      const Offset(170, 104),
      size: 27,
      color: color,
    );
    _text(
      canvas,
      type == GameType.symmetry
          ? (identity ? '¿Son idénticas?' : '¿Es su reflejo?')
          : '¿Girada 90° a la derecha?',
      const Offset(170, 27),
      size: 14,
    );
    for (final (label, left) in [('Sí', 65.0), ('No', 181.0)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 192, 94, 40),
          const Radius.circular(10),
        ),
        Paint()..color = color.withValues(alpha: .14),
      );
      _text(canvas, label, Offset(left + 47, 212), color: color, size: 16);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReasoningDemoPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.index != index ||
      oldDelegate.color != color;
}
