import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/stroke_equation.dart';

class StrokeEquationGame extends StatelessWidget {
  const StrokeEquationGame({
    super.key,
    required this.question,
    required this.onSubmit,
  });
  final StrokeEquationQuestion question;
  final ValueChanged<Object> onSubmit;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      StrokeEquationPanels(question: question),
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: () => onSubmit(true),
              child: const Text('Sí'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: OutlinedButton(
              onPressed: () => onSubmit(false),
              child: const Text('No'),
            ),
          ),
        ],
      ),
    ],
  );
}

class StrokeEquationPanels extends StatelessWidget {
  const StrokeEquationPanels({
    super.key,
    required this.question,
    this.reveal = 1,
  });
  final StrokeEquationQuestion question;
  final double reveal;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600;
      final side = math.min(
        210.0,
        (constraints.maxWidth - (wide ? 80 : 40)) / (wide ? 3 : 2),
      );
      Widget board(
        List<LineStroke> lines,
        String label, {
        double progress = 1,
      }) => Semantics(
        image: true,
        label: '$label: ${lines.length} trazos',
        child: SizedBox.square(
          dimension: side,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: StrokePanelPainter(lines, reveal: progress),
            ),
          ),
        ),
      );
      const plus = SizedBox(
        width: 40,
        child: Center(
          child: Text(
            '+',
            style: TextStyle(fontSize: 32, color: AppColors.muted),
          ),
        ),
      );
      const equals = SizedBox(
        width: 40,
        child: Center(
          child: Text(
            '=',
            style: TextStyle(fontSize: 32, color: AppColors.muted),
          ),
        ),
      );
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              board(question.left, 'Primer panel'),
              plus,
              board(question.right, 'Segundo panel'),
              if (wide) ...[
                equals,
                board(question.result, 'Resultado propuesto', progress: reveal),
              ],
            ],
          ),
          if (!wide) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                equals,
                board(question.result, 'Resultado propuesto', progress: reveal),
                const SizedBox(width: 40),
              ],
            ),
          ],
        ],
      );
    },
  );
}

class StrokePanelPainter extends CustomPainter {
  const StrokePanelPainter(this.strokes, {this.reveal = 1});
  final List<LineStroke> strokes;
  final double reveal;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = const Color(0xFF26376E),
    );
    final margin = size.width * .12;
    final scale = (size.width - margin * 2) / LineStroke.extent;
    Offset position(TracePoint p) =>
        Offset(margin + p.x * scale, margin + p.y * scale);
    final dots = Paint()..color = const Color(0xFFFFF7DE).withValues(alpha: .5);
    for (var y = 0; y <= 6; y++) {
      for (var x = 0; x <= 6; x++) {
        canvas.drawCircle(
          position((x: x * 12, y: y * 12)),
          math.max(.7, size.width * .006),
          dots,
        );
      }
    }
    final pen = Paint()
      ..color = const Color(0xFFFFF7DE)
      ..strokeWidth = math.max(1.25, size.width * .012)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < strokes.length; i++) {
      final progress = (reveal * strokes.length - i).clamp(0.0, 1.0);
      if (progress > 0) {
        canvas.drawLine(
          position(strokes[i].start),
          Offset.lerp(
            position(strokes[i].start),
            position(strokes[i].end),
            progress,
          )!,
          pen,
        );
      }
    }
  }

  @override
  bool shouldRepaint(StrokePanelPainter old) =>
      old.strokes != strokes || old.reveal != reveal;
}

/// Demonstration only: this animation is never attached to a scored question.
class StrokeEquationWalkthrough extends StatefulWidget {
  const StrokeEquationWalkthrough({super.key});
  @override
  State<StrokeEquationWalkthrough> createState() =>
      _StrokeEquationWalkthroughState();
}

class _StrokeEquationWalkthroughState extends State<StrokeEquationWalkthrough>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  final _valid = StrokeEquationGenerator.example();
  final _invalid = StrokeEquationGenerator.example(correct: false);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _motion.stop();
      _motion.value = .45;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) {
      final correct = _motion.value < .5;
      final progress = ((_motion.value % .5) * 3).clamp(0.0, 1.0);
      return Column(
        children: [
          StrokeEquationPanels(
            question: correct ? _valid : _invalid,
            reveal: progress,
          ),
          const SizedBox(height: 16),
          Text(
            correct
                ? 'Sí · conserva todos los trazos.'
                : 'No · aparece un trazo adicional en el centro.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      );
    },
  );
}
