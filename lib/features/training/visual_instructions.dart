import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import 'mixed_walkthrough.dart';
import 'stroke_equation.dart';
import 'switch_challenge.dart';

/// A preview has its own decorative animation and never starts a scored round.
class VisualInstructions extends StatelessWidget {
  const VisualInstructions({
    super.key,
    required this.type,
    required this.settings,
    required this.roundIndex,
    required this.totalRounds,
    required this.onAccept,
  });

  final GameType type;
  final TrainingSettings settings;
  final int roundIndex;
  final int totalRounds;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      GameType.memory => AppColors.green,
      GameType.grid => AppColors.purple,
      GameType.symmetry => const Color(0xFF4B82A1),
      GameType.switcher => AppColors.amber,
      GameType.math => AppColors.coral,
      GameType.strokes => const Color(0xFF405CA0),
      GameType.mixed => const Color(0xFF237A9E),
    };
    final steps = switch (type) {
      GameType.memory => const [
        (
          'Observa cada punto',
          'El círculo rojo numerado aparece sobre un plano de24 círculos aleatorios. Cada presentación dura 3.5 s: se desvanece 0.5 s y reaparece 0.5 s.',
        ),
        (
          'Conserva el orden',
          'Memoriza 3, 4 o 5posiciones consecutivas. Los demás círculos permanecen como referencias y distractores.',
        ),
        (
          'Marca la secuencia',
          'Tienes 5 segundos para elegir las posiciones en orden. Se numeran 1 a N sobre el mismo plano y el tiempo vencido avanza automáticamente.',
        ),
      ],
      GameType.grid || GameType.symmetry || GameType.mixed => [
        (
          'Primero, el punto',
          'Observa el círculo rojo y su número durante 3.5 s. Se desvanece y reaparece en fases suaves de 0.5 s sobre un plano aleatorio.',
        ),
        (
          'Después, la figura',
          type == GameType.grid
              ? 'Resuelve Grid en 5 segundos. Flecha curva: giro a la derecha; +: unión de patrones. Responde Sí/No.'
              : type == GameType.symmetry
              ? 'Resuelve Simetría o identidad en 5 segundos. = compara identidad; el espejo indica el eje. Responde Sí/No.'
              : 'Resuelve una figura en 5 segundos. Se alternan Grid y Simetría/identidad entre los puntos.',
        ),
        (
          'Recupera al final',
          'Se repiten 3, 4 o 5 pares punto → figura, incluida la última figura. Después tienes 5 segundos para marcar la secuencia 1 a N. Los plazos vencidos avanzan automáticamente.',
        ),
      ],
      GameType.switcher => const [
        (
          'Lee las posiciones',
          'Numera las figuras de izquierda a derecha: 1, 2, 3 y 4.',
        ),
        (
          'Aplica el primer filtro',
          '1342 toma las posiciones 1, 3, 4 y 2, en ese orden.',
        ),
        (
          'Elige el segundo filtro',
          'Toca la regla que convierte esa secuencia intermedia en la fila inferior.',
        ),
      ],
      GameType.strokes => const [
        (
          'Superpón',
          'Suma mentalmente las líneas de los dos paneles. Los trazos compartidos se dibujan una sola vez.',
        ),
        (
          'Compara con precisión',
          'El resultado debe conservar todas las líneas, sus extremos y uniones exactas. Una ausencia, adición, deformación o desplazamiento mínimo invalida la figura.',
        ),
        (
          'Responde',
          'Sí para una superposición exacta; No si encuentras cualquier diferencia. La partida muestra solo la ecuación y los controles.',
        ),
      ],
      GameType.math => const [
        (
          'Observa el objetivo',
          'Aparecen entre 2 y 6 espacios aleatorios. Completa la operación con todas las fichas para alcanzar el número indicado.',
        ),
        (
          'Ordena las fichas',
          'Cada ejercicio trae operadores aleatorios + − × ÷ que se mantienen mientras respondes. Usa cada ficha una vez; siempre existe una solución y se aceptan alternativas válidas.',
        ),
        (
          'Confirma el cálculo',
          'Multiplica y divide antes de sumar y restar. Puedes deshacer antes de confirmar.',
        ),
      ],
    };
    final reduced = reduceMotion(context);
    final instructions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[i].$1,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      steps[i].$2,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (i != steps.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
    final Widget demo = switch (type) {
      GameType.memory ||
      GameType.grid ||
      GameType.symmetry ||
      GameType.mixed => MixedSequenceWalkthrough(type: type),
      GameType.switcher => const SwitchWalkthrough(),
      GameType.strokes => const StrokeEquationWalkthrough(),
      _ => _InstructionDemo(type: type, color: color, reducedMotion: reduced),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Text(
          totalRounds == 1
              ? 'Práctica individual'
              : 'Reto ${roundIndex + 1} de $totalRounds · Test completo',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          type.title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 9),
        Text(
          'Conoce la dinámica antes de empezar.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _InfoChip(
              icon: Icons.timer_outlined,
              label: '${settings.durationFor(type).inMinutes} minutos',
            ),
            _InfoChip(
              icon: Icons.tune_rounded,
              label: settings.difficulty.title,
            ),
            const _InfoChip(
              icon: Icons.lock_outline_rounded,
              label: 'Resultados al final',
            ),
          ],
        ),
        const SizedBox(height: 24),
        SurfacePanel(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 660) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 11, child: demo),
                    const SizedBox(width: 30),
                    Expanded(flex: 10, child: instructions),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [demo, const SizedBox(height: 28), instructions],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.pause_circle_outline_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Tómate tu tiempo. El cronómetro empieza cuando aceptes.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: onAccept,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Entendido, empezar'),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

class _InstructionDemo extends StatefulWidget {
  const _InstructionDemo({
    required this.type,
    required this.color,
    required this.reducedMotion,
  });
  final GameType type;
  final Color color;
  final bool reducedMotion;

  @override
  State<_InstructionDemo> createState() => _InstructionDemoState();
}

class _InstructionDemoState extends State<_InstructionDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _InstructionDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.reducedMotion) {
      _animation.stop();
      _animation.value = .95;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  String _phase(double progress) => switch (widget.type) {
    GameType.memory =>
      progress < .32
          ? '01 · Observa las posiciones'
          : progress < .52
          ? '02 · Guarda la imagen en tu memoria'
          : '03 · Repite las posiciones',
    GameType.symmetry =>
      'Compara identidad o reflejo, después recuerda los puntos.',
    GameType.grid =>
      progress < .25
          ? '01 · Observa el patrón de origen'
          : progress < .7
          ? '02 · Aplica el giro de 90°'
          : '03 · Compara y responde',
    GameType.switcher =>
      progress < .3
          ? '01 · Lee las cuatro posiciones'
          : progress < .65
          ? '02 · Aplica el filtro 1342'
          : '03 · Elige 3241 para llegar al objetivo',
    GameType.strokes => 'Superpón y compara los trazos.',
    GameType.mixed => 'Punto → figura → recuperación ordenada.',
    GameType.math =>
      progress < .2
          ? '01 · El objetivo es 34'
          : progress < .8
          ? '02 · Coloca 8, 4 y 2 en ese orden'
          : '03 · 8 × 4 + 2 = 34',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(
            widget.reducedMotion
                ? Icons.image_outlined
                : Icons.play_circle_outline_rounded,
            color: widget.color,
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              widget.reducedMotion ? 'EJEMPLO GUIADO' : 'EJEMPLO ANIMADO',
              style: TextStyle(
                color: widget.color,
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 15),
      Semantics(
        label: switch (widget.type) {
          GameType.memory => 'Ejemplo de memoria: observa puntos en fila 2 columna 2, fila 3 columna 4 y fila 5 columna 4. Al desaparecer, selecciona esas mismas posiciones.',
          GameType.symmetry => 'Ejemplo de simetría: compara las figuras y recuerda los puntos en su orden de aparición.',
          GameType.grid => 'Ejemplo espacial: la segunda cuadrícula es un giro de 90 grados a la derecha de la primera. La respuesta es Sí.',
          GameType.switcher => 'Ejemplo de filtros: círculo, triángulo, cruz y cuadrado pasan por 1342 y luego 3241 para obtener cuadrado, cruz, triángulo y círculo.',
          GameType.mixed =>
            'Ejemplo de puntos intercalados con Grid y Simetría.',
          GameType.strokes =>
            'Ejemplo: superposición de dos trazos para formar una H.',
          GameType.math => 'Ejemplo numérico: las fichas 8, 4 y 2 forman 8 por 4 más 2 igual a 34.',
        },
        image: true,
        child: ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ColoredBox(
              color: AppColors.background,
              child: SizedBox(
                height: 264,
                width: double.infinity,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _DemoPainter(
                      animation: _animation,
                      type: widget.type,
                      color: widget.color,
                      reducedMotion: widget.reducedMotion,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => Text(
          _phase(_animation.value),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: widget.color,
          ),
        ),
      ),
    ],
  );
}

class _DemoPainter extends CustomPainter {
  _DemoPainter({
    required this.animation,
    required this.type,
    required this.color,
    required this.reducedMotion,
  }) : super(repaint: animation);
  final Animation<double> animation;
  final GameType type;
  final Color color;
  final bool reducedMotion;

  double _range(double value, double start, double end) =>
      ((value - start) / (end - start)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min((size.width - 16) / 340, (size.height - 12) / 250);
    canvas.save();
    canvas.translate(
      (size.width - 340 * scale) / 2,
      (size.height - 250 * scale) / 2,
    );
    canvas.scale(scale);
    switch (type) {
      case GameType.memory:
        _memory(canvas, animation.value);
      case GameType.symmetry:
      case GameType.grid:
      case GameType.mixed:
        _grid(canvas, animation.value);
      case GameType.switcher:
        _switcher(canvas, animation.value);
      case GameType.strokes:
        break; // This game has a dedicated animated walkthrough.
      case GameType.math:
        _math(canvas, animation.value);
    }
    canvas.restore();
  }

  void _label(
    Canvas canvas,
    String text,
    Offset center, {
    double size = 12,
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w600,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'FiraSans',
          color: color,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _box(
    Canvas canvas,
    Rect rect,
    Color fill, {
    double radius = 12,
    Color? border,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = fill,
    );
    if (border != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _memory(Canvas canvas, double progress) {
    const origin = Offset(64, 15);
    const side = 212.0;
    const step = side / 6;
    const targets = [7, 15, 27];
    _box(canvas, origin & const Size.square(side), AppColors.ink, radius: 17);
    final observing = progress < .32;
    final selectedCount = ((_range(progress, .52, .85) * 3).ceil()).clamp(0, 3);
    for (var i = 0; i < 36; i++) {
      final pos = origin + Offset((i % 6 + .5) * step, (i ~/ 6 + .5) * step);
      final target = targets.indexOf(i);
      final selected = target >= 0 && target < selectedCount;
      if (selected) {
        _box(
          canvas,
          Rect.fromCenter(center: pos, width: 29, height: 29),
          color.withValues(alpha: .55),
          radius: 7,
          border: AppColors.mint.withValues(alpha: .65),
        );
      }
      final visible = target >= 0 && (observing || selected);
      canvas.drawCircle(
        pos,
        visible ? 5.5 : 1.5,
        Paint()
          ..color = visible
              ? AppColors.mint
              : Colors.white.withValues(alpha: .2),
      );
      if (selected &&
          target == selectedCount - 1 &&
          progress < .88 &&
          !reducedMotion) {
        final pulse = (_range(progress, .52, .85) * 3) % 1;
        canvas.drawCircle(
          pos,
          8 + pulse * 11,
          Paint()
            ..color = AppColors.mint.withValues(alpha: (1 - pulse) * .6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
    _label(
      canvas,
      observing
          ? 'OBSERVA'
          : progress < .52
          ? 'RECUERDA'
          : '$selectedCount DE 3 POSICIONES',
      const Offset(170, 242),
      color: color,
      size: 11,
    );
  }

  void _pattern(
    Canvas canvas,
    Offset origin,
    List<int> cells, {
    double angle = 0,
  }) {
    canvas.save();
    canvas.translate(origin.dx + 62, origin.dy + 62);
    _box(
      canvas,
      const Rect.fromLTWH(-62, -62, 124, 124),
      AppColors.ink,
      radius: 14,
    );
    canvas.rotate(angle);
    for (var i = 0; i < 25; i++) {
      final pos = Offset((i % 5 - 2) * 21.0, (i ~/ 5 - 2) * 21.0);
      if (cells.contains(i)) {
        _box(
          canvas,
          Rect.fromCenter(center: pos, width: 13, height: 13),
          AppColors.mint,
          radius: 3,
        );
      } else {
        canvas.drawCircle(
          pos,
          1.5,
          Paint()..color = Colors.white.withValues(alpha: .3),
        );
      }
    }
    canvas.restore();
  }

  void _grid(Canvas canvas, double progress) {
    const cells = [0, 5, 10, 11, 12, 17, 22];
    final rotation =
        Curves.easeInOutCubic.transform(_range(progress, .25, .65)) *
        math.pi /
        2;
    _label(
      canvas,
      'ORIGEN',
      const Offset(74, 22),
      size: 11,
      color: AppColors.muted,
    );
    _label(
      canvas,
      'GIRO A LA DERECHA',
      const Offset(266, 22),
      size: 11,
      color: AppColors.muted,
    );
    _pattern(canvas, const Offset(12, 45), cells);
    _pattern(canvas, const Offset(204, 45), cells, angle: rotation);
    _label(canvas, '90°', const Offset(170, 98), color: color, size: 23);
    _label(canvas, '→', const Offset(170, 126), color: color, size: 24);
    _box(
      canvas,
      const Rect.fromLTWH(74, 195, 90, 39),
      progress >= .7 ? color : Colors.white,
      radius: 10,
      border: color.withValues(alpha: .2),
    );
    _label(
      canvas,
      '✓  Sí',
      const Offset(119, 215),
      color: progress >= .7 ? Colors.white : color,
      size: 16,
    );
    _box(
      canvas,
      const Rect.fromLTWH(178, 195, 90, 39),
      Colors.white,
      radius: 10,
      border: AppColors.line,
    );
    _label(
      canvas,
      'No',
      const Offset(223, 215),
      color: AppColors.muted,
      size: 16,
    );
  }

  void _shape(Canvas canvas, int shape, Offset center, {double opacity = 1}) {
    final paint = Paint()
      ..color = [
        AppColors.green,
        AppColors.amber,
        AppColors.purple,
        AppColors.coral,
      ][shape].withValues(alpha: opacity);
    final rect = Rect.fromCenter(center: center, width: 23, height: 23);
    if (shape == 0) {
      canvas.drawCircle(center, 11.5, paint);
    } else if (shape == 1) {
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy - 12)
          ..lineTo(center.dx + 12, center.dy + 11)
          ..lineTo(center.dx - 12, center.dy + 11)
          ..close(),
        paint,
      );
    } else if (shape == 2) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 9, height: 25),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 25, height: 9),
          const Radius.circular(2),
        ),
        paint,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paint,
      );
    }
  }

  void _switcher(Canvas canvas, double progress) {
    const input = [0, 1, 2, 3];
    const output = [3, 2, 1, 0];
    for (var i = 0; i < 4; i++) {
      final x = 83.0 + i * 58;
      _box(
        canvas,
        Rect.fromCenter(center: Offset(x, 28), width: 47, height: 43),
        Colors.white,
        radius: 10,
        border: AppColors.line,
      );
      _shape(canvas, input[i], Offset(x, 28));
      _label(
        canvas,
        '${i + 1}',
        Offset(x, 61),
        color: AppColors.muted,
        size: 10,
      );
    }
    final line = Paint()
      ..color = color.withValues(alpha: .25)
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(170, 73), const Offset(170, 204), line);
    _box(
      canvas,
      const Rect.fromLTWH(126, 75, 88, 33),
      AppColors.ink,
      radius: 9,
    );
    _label(
      canvas,
      '1 3 4 2',
      const Offset(170, 91),
      color: Colors.white,
      size: 17,
    );
    for (var i = 0; i < 3; i++) {
      final chosen = progress >= .65 && i == 2;
      final rect = Rect.fromLTWH(38 + i * 91, 136, 82, 36);
      _box(
        canvas,
        rect,
        chosen ? color : Colors.white,
        radius: 9,
        border: chosen ? color : AppColors.line,
      );
      _label(
        canvas,
        ['1342', '2341', '3241'][i],
        rect.center,
        color: chosen ? Colors.white : AppColors.ink,
        size: 17,
      );
    }
    final fade = _range(progress, .65, .85);
    for (var i = 0; i < 4; i++) {
      final x = 83.0 + i * 58;
      final y = 218 + (1 - fade) * -12;
      _box(
        canvas,
        Rect.fromCenter(center: Offset(x, 218), width: 47, height: 43),
        Colors.white,
        radius: 10,
        border: AppColors.line,
      );
      _shape(canvas, output[i], Offset(x, y), opacity: .2 + .8 * fade);
    }
    if (!reducedMotion) {
      final y = 112 + (progress * 4 % 1) * 18;
      canvas.drawCircle(Offset(170, y), 3, Paint()..color = color);
    }
  }

  void _math(Canvas canvas, double progress) {
    _label(
      canvas,
      'OBJETIVO 34',
      const Offset(170, 24),
      color: color,
      size: 12,
    );
    _box(
      canvas,
      const Rect.fromLTWH(14, 51, 312, 78),
      AppColors.ink,
      radius: 15,
    );
    const slotX = [47.0, 118.0, 189.0];
    const numbers = [8, 4, 2];
    for (var i = 0; i < 3; i++) {
      _box(
        canvas,
        Rect.fromCenter(center: Offset(slotX[i], 90), width: 44, height: 48),
        Colors.white.withValues(alpha: .08),
        radius: 9,
        border: Colors.white.withValues(alpha: .15),
      );
      final source = Offset(110.0 + i * 60, 182);
      final amount = Curves.easeOutCubic.transform(
        _range(progress, .2 + i * .18, .35 + i * .18),
      );
      _box(
        canvas,
        Rect.fromCenter(center: source, width: 45, height: 46),
        amount == 0 ? Colors.white : color.withValues(alpha: .07),
        radius: 10,
        border: AppColors.line,
      );
      if (amount > 0 && amount < 1) {
        _label(
          canvas,
          '${numbers[i]}',
          source,
          size: 21,
          color: color.withValues(alpha: .18),
        );
      }
      final pos = Offset.lerp(source, Offset(slotX[i], 90), amount)!;
      _label(
        canvas,
        '${numbers[i]}',
        pos,
        size: 24,
        color: amount > .7 ? Colors.white : color,
      );
    }
    _label(canvas, '×', const Offset(83, 90), color: AppColors.mint, size: 23);
    _label(canvas, '+', const Offset(154, 90), color: AppColors.mint, size: 23);
    _label(
      canvas,
      '= 34',
      const Offset(266, 90),
      color: AppColors.mint,
      size: 27,
    );
    _label(
      canvas,
      progress >= .8 ? '8 × 4 + 2 = 34   ✓' : 'TOCA LAS FICHAS EN ORDEN',
      const Offset(170, 234),
      color: color,
      size: progress >= .8 ? 17 : 11,
    );
  }

  @override
  bool shouldRepaint(covariant _DemoPainter oldDelegate) =>
      type != oldDelegate.type ||
      color != oldDelegate.color ||
      reducedMotion != oldDelegate.reducedMotion;
}
