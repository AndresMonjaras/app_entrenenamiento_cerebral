import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../../domain/question_generator.dart';

const _shapeNames = ['círculo', 'triángulo', 'cruz', 'cuadrado'];
const _funnelBlue = Color(0xFF243B8C);
const _shapeColors = [
  Color(0xFF139E86),
  Color(0xFFBBD768),
  Color(0xFF217CC0),
  Color(0xFFC52636),
];
const _switchDiagramVerticalPadding = 12.0;
const _switchInputHeight = 64.0;
const _switchFilterWidth = 114.0;
const _switchFilterHeight = 48.0;
const _switchFilterHorizontalPadding = 10.0;
const _switchCanopyHeight = 48.0;

/// Both scored Switch modes use the same vertical, two-filter diagram.
/// The input and target stay visible; only a held option previews its mapping.
class MinijuegoSwitchChallenge extends StatefulWidget {
  const MinijuegoSwitchChallenge({
    super.key,
    required this.question,
    required this.onSubmit,
  });

  final SwitchQuestion question;
  final ValueChanged<Object> onSubmit;

  @override
  State<MinijuegoSwitchChallenge> createState() =>
      _MinijuegoSwitchChallengeState();
}

class _MinijuegoSwitchChallengeState extends State<MinijuegoSwitchChallenge> {
  int? _preview;
  bool _submitted = false;

  @override
  void didUpdateWidget(covariant MinijuegoSwitchChallenge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question) {
      _preview = null;
      _submitted = false;
    }
  }

  void _answer(int index) {
    if (_submitted) return;
    setState(() => _submitted = true);
    widget.onSubmit(index);
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final intermediate = applyPermutation(question.input, question.firstRule);
    return _SwitchDiagram(
      input: question.input,
      firstRule: question.firstRule,
      target: question.output,
      optionCount: question.options.length,
      optionBuilder: (index) => _RuleOption(
        key: ValueKey('switch-option-$index'),
        rule: question.options[index],
        shapes: applyPermutation(intermediate, question.options[index]),
        revealed: _preview == index,
        reducedMotion: reduceMotion(context),
        onHighlight: (value) {
          if (!mounted || _submitted) return;
          setState(() => _preview = value ? index : null);
        },
        onTap: _submitted ? null : () => _answer(index),
      ),
    );
  }
}

/// A slow, unscored 24-second example. Automatic option trials occur here only.
class SwitchWalkthrough extends StatefulWidget {
  const SwitchWalkthrough({super.key});

  @override
  State<SwitchWalkthrough> createState() => _SwitchWalkthroughState();
}

class _SwitchWalkthroughState extends State<SwitchWalkthrough>
    with SingleTickerProviderStateMixin {
  static const _input = [0, 1, 2, 3];
  static const _first = [1, 3, 4, 2];
  static const _options = [
    [1, 3, 4, 2],
    [2, 3, 4, 1],
    [3, 2, 4, 1],
  ];
  static const _target = [3, 2, 1, 0];

  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _timeline.stop();
      _timeline.value = .94;
    } else if (!_timeline.isAnimating) {
      _timeline.repeat();
    }
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  String _phase(double seconds) {
    if (seconds < 4) return '01 · Las figuras entran en el primer filtro';
    if (seconds < 8) {
      return '02 · 1342 produce círculo, cruz, cuadrado, triángulo';
    }
    if (seconds < 12) return '03 · Prueba 1342 y compara sus figuras';
    if (seconds < 16) return '03 · Prueba 2341 y compara sus figuras';
    return '04 · 3241 coincide con el objetivo';
  }

  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotion(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          reduced ? 'EJEMPLO GUIADO' : 'EJEMPLO ANIMADO',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.amber,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _SwitchExampleBoard(
          input: _input,
          firstRule: _first,
          options: _options,
          target: _target,
          animation: reduced ? const AlwaysStoppedAnimation(.94) : _timeline,
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _timeline,
          builder: (context, child) => Text(
            _phase(_timeline.value * 24),
            key: const ValueKey('switch-demo-phase'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.amber,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

const _switchExampleColors = [
  Color(0xFF2B7D67),
  Color(0xFFC88B32),
  Color(0xFF8B74B5),
  Color(0xFFD17E69),
];
const _switchExampleInk = Color(0xFF1B3038);
const _switchExampleLine = Color(0xFFE1E6E0);
const _switchExampleCanvas = Color(0xFFF5F5F3);

/// The instruction board follows the supplied reference: input and first
/// filter on the upper left, transformed figures to the right, then two
/// unselected rules, the selected rule, and the fixed target row.
class _SwitchExampleBoard extends StatelessWidget {
  const _SwitchExampleBoard({
    required this.input,
    required this.firstRule,
    required this.options,
    required this.target,
    required this.animation,
  });

  final List<int> input;
  final List<int> firstRule;
  final List<List<int>> options;
  final List<int> target;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 284),
      child: AspectRatio(
        aspectRatio: 284 / 458,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: _switchExampleCanvas,
            child: Semantics(
              label: 'Ejemplo animado de Switch Challenge. Cuatro figuras pasan por el filtro 1342. Después se comparan las reglas 1342, 2341 y 3241 con la secuencia objetivo cuadrado, cruz, triángulo, círculo.',
              image: true,
              child: ExcludeSemantics(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _SwitchExamplePainter(
                          input: input,
                          firstRule: firstRule,
                          options: options,
                          target: target,
                          animation: animation,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 58,
                      child: IgnorePointer(
                        child: SizedBox(
                          key: const ValueKey('switch-input-sequence'),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 60,
                      child: IgnorePointer(
                        child: SizedBox(
                          key: const ValueKey('switch-static-target'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SwitchExamplePainter extends CustomPainter {
  _SwitchExamplePainter({
    required this.input,
    required this.firstRule,
    required this.options,
    required this.target,
    required this.animation,
  }) : super(repaint: animation);

  final List<int> input;
  final List<int> firstRule;
  final List<List<int>> options;
  final List<int> target;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    const board = Size(284, 458);
    final scale = math.min(
      size.width / board.width,
      size.height / board.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - board.width * scale) / 2,
      (size.height - board.height * scale) / 2,
    );
    canvas.scale(scale);

    final seconds = animation.value * 24;
    final selected = seconds < 8
        ? -1
        : seconds < 12
        ? 0
        : seconds < 16
        ? 1
        : 2;
    _drawInput(canvas);
    _drawFunnel(canvas);
    _drawFirstFilterAndOutput(canvas, seconds);
    _drawDownArrow(canvas);
    for (var index = 0; index < options.length; index++) {
      final rect = switch (index) {
        0 => const Rect.fromLTWH(12, 182, 125, 80),
        1 => const Rect.fromLTWH(147, 182, 125, 80),
        _ => const Rect.fromLTWH(79.5, 272, 125, 80),
      };
      _drawOption(canvas, rect, options[index], selected == index);
    }
    _drawFlag(canvas);
    _drawTarget(canvas, target);
    if (seconds < 4) _flowInputToFilter(canvas, seconds / 4);
    if (seconds >= 4 && seconds < 8) {
      _flowFilterToOutput(canvas, (seconds - 4) / 4);
    }

    canvas.restore();
  }

  void _drawInput(Canvas canvas) {
    for (var index = 0; index < input.length; index++) {
      final center = Offset(42 + index * 34, 33);
      _drawTile(canvas, center, input[index], side: 26, shapeSide: 18);
      _drawText(
        canvas,
        '${index + 1}',
        Offset(center.dx, 54),
        size: 8,
        color: const Color(0xFF77817D),
        weight: FontWeight.w600,
      );
    }
  }

  void _drawFunnel(Canvas canvas) {
    final green = Paint()..color = _switchExampleColors[0];
    final mint = Paint()..color = const Color(0xFFD1E4DA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(66, 65, 52, 4),
        const Radius.circular(3),
      ),
      green,
    );
    canvas.drawPath(
      Path()
        ..moveTo(68, 71)
        ..lineTo(116, 71)
        ..lineTo(99, 94)
        ..lineTo(85, 94)
        ..close(),
      mint,
    );
    canvas.drawRect(const Rect.fromLTWH(86, 94, 12, 7), mint);
  }

  void _drawFirstFilterAndOutput(Canvas canvas, double seconds) {
    _drawRRect(
      canvas,
      const Rect.fromLTWH(50, 102, 83, 33),
      _switchExampleInk,
      radius: 9,
    );
    if (seconds < 4 || seconds >= 8) {
      _drawText(
        canvas,
        firstRule.join(' '),
        const Offset(91.5, 118.5),
        size: 17,
        color: Colors.white,
        weight: FontWeight.w700,
        letterSpacing: 2,
      );
    }
    _drawArrow(canvas, const Offset(141, 119), const Offset(155, 119));
    final output = [for (final position in firstRule) input[position - 1]];
    for (var index = 0; index < output.length; index++) {
      final center = Offset(176 + index * 24, 119);
      _drawTile(
        canvas,
        center,
        seconds >= 8 ? output[index] : null,
        side: 20,
        shapeSide: 16,
      );
    }
  }

  void _drawDownArrow(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF7D8884)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(142, 153)
        ..lineTo(142, 171)
        ..moveTo(136, 165)
        ..lineTo(142, 171)
        ..lineTo(148, 165),
      paint,
    );
  }

  void _drawOption(Canvas canvas, Rect rect, List<int> rule, bool active) {
    final matching = active && listEquals(rule, options.last);
    final fill = matching ? const Color(0xFFDEF1E5) : Colors.white;
    final stroke = matching
        ? _switchExampleColors[0]
        : active
        ? const Color(0xFF6F9989)
        : _switchExampleLine;
    _drawRRect(
      canvas,
      rect,
      fill,
      radius: 12,
      border: stroke,
      borderWidth: 1.3,
    );
    _drawText(
      canvas,
      rule.join(' '),
      Offset(rect.center.dx, rect.top + 27),
      size: 19,
      weight: FontWeight.w700,
      letterSpacing: 3,
    );
    if (active) {
      final intermediate = [
        for (final position in firstRule) input[position - 1],
      ];
      final result = [for (final position in rule) intermediate[position - 1]];
      for (var index = 0; index < result.length; index++) {
        _drawExampleShape(
          canvas,
          result[index],
          Offset(
            rect.left + 22 + index * ((rect.width - 44) / 3),
            rect.top + 58,
          ),
          16,
        );
      }
    } else {
      for (var index = 0; index < 4; index++) {
        canvas.drawCircle(
          Offset(
            rect.left + 22 + index * ((rect.width - 44) / 3),
            rect.top + 58,
          ),
          1.6,
          Paint()..color = const Color(0xFFE1E7E1),
        );
      }
    }
  }

  void _drawFlag(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF77817D)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    canvas.drawPath(
      Path()
        ..moveTo(138, 376)
        ..lineTo(138, 388)
        ..moveTo(138, 377)
        ..lineTo(147, 377)
        ..lineTo(147, 383)
        ..lineTo(141, 383)
        ..lineTo(141, 381)
        ..lineTo(138, 381),
      paint,
    );
  }

  void _drawTarget(Canvas canvas, List<int> shapes) {
    for (var index = 0; index < shapes.length; index++) {
      _drawTile(
        canvas,
        Offset(44 + index * 65, 422),
        shapes[index],
        side: 56,
        height: 48,
        shapeSide: 22,
      );
    }
  }

  void _flowInputToFilter(Canvas canvas, double value) {
    final progress = Curves.easeInOutCubic.transform(
      value.clamp(0, 1).toDouble(),
    );
    final intermediate = [
      for (final position in firstRule) input[position - 1],
    ];
    for (var source = 0; source < input.length; source++) {
      final destination = firstRule.indexOf(source + 1);
      final start = Offset(42 + source * 34, 33);
      final end = Offset(61 + destination * 20.5, 118.5);
      _drawExampleShape(
        canvas,
        intermediate[destination],
        Offset.lerp(start, end, progress)!,
        18,
      );
    }
  }

  void _flowFilterToOutput(Canvas canvas, double value) {
    final progress = Curves.easeInOutCubic.transform(
      value.clamp(0, 1).toDouble(),
    );
    final intermediate = [
      for (final position in firstRule) input[position - 1],
    ];
    for (var index = 0; index < intermediate.length; index++) {
      final start = Offset(61 + index * 20.5, 118.5);
      final end = Offset(176 + index * 24, 119);
      _drawExampleShape(
        canvas,
        intermediate[index],
        Offset.lerp(start, end, progress)!,
        18,
      );
    }
  }

  void _drawTile(
    Canvas canvas,
    Offset center,
    int? shape, {
    required double side,
    double? height,
    required double shapeSide,
  }) {
    _drawRRect(
      canvas,
      Rect.fromCenter(center: center, width: side, height: height ?? side),
      Colors.white,
      radius: math.min(side * .28, 7),
      border: _switchExampleLine,
      borderWidth: .8,
    );
    if (shape != null) _drawExampleShape(canvas, shape, center, shapeSide);
  }

  void _drawRRect(
    Canvas canvas,
    Rect rect,
    Color color, {
    double radius = 0,
    Color? border,
    double borderWidth = 1,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = color);
    if (border != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end) {
    final paint = Paint()
      ..color = const Color(0xFF7D8884)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(end.dx, end.dy)
        ..lineTo(end.dx - 5, end.dy - 5)
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - 5, end.dy + 5),
      paint,
    );
  }

  void _drawText(
    Canvas canvas,
    String value,
    Offset center, {
    required double size,
    Color color = _switchExampleInk,
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'FiraSans',
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SwitchExamplePainter oldDelegate) =>
      !listEquals(input, oldDelegate.input) ||
      !listEquals(firstRule, oldDelegate.firstRule) ||
      !listEquals(options, oldDelegate.options) ||
      !listEquals(target, oldDelegate.target) ||
      animation != oldDelegate.animation;
}

void _drawExampleShape(Canvas canvas, int shape, Offset center, double side) {
  final paint = Paint()..color = _switchExampleColors[shape];
  final box = Rect.fromCenter(center: center, width: side, height: side);
  switch (shape) {
    case 0:
      canvas.drawCircle(center, side / 2, paint);
    case 1:
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, box.top)
          ..lineTo(box.right, box.bottom)
          ..lineTo(box.left, box.bottom)
          ..close(),
        paint,
      );
    case 2:
      for (final dimensions in [
        Size(side * .34, side),
        Size(side, side * .34),
      ]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: dimensions.width,
              height: dimensions.height,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    default:
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(2)),
        paint,
      );
  }
}

class _SwitchDiagram extends StatelessWidget {
  const _SwitchDiagram({
    required this.input,
    required this.firstRule,
    required this.target,
    required this.optionCount,
    required this.optionBuilder,
  });

  final List<int> input;
  final List<int> firstRule;
  final List<int> target;
  final int optionCount;
  final Widget Function(int) optionBuilder;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: ColoredBox(
        color: const Color(0xFFF5F3EA),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: _switchDiagramVerticalPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShapeSequence(
                key: const ValueKey('switch-input-sequence'),
                shapes: input,
                label: 'Secuencia inicial',
              ),
              const _Canopy(key: ValueKey('switch-upper-canopy')),
              Semantics(
                label: 'Primer filtro ${firstRule.join(', ')}',
                excludeSemantics: true,
                child: Container(
                  key: const ValueKey('switch-first-rule'),
                  width: _switchFilterWidth,
                  height: _switchFilterHeight,
                  decoration: BoxDecoration(
                    color: _funnelBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: _switchFilterHorizontalPadding,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      firstRule.join(' '),
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _BranchConnector(
                key: const ValueKey('switch-options-arrow'),
                count: optionCount,
              ),
              SizedBox(
                height: 88,
                child: Row(
                  children: [
                    for (var index = 0; index < optionCount; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(
                        key: ValueKey('opt_$index'),
                        child: optionBuilder(index),
                      ),
                    ],
                  ],
                ),
              ),
              _BranchConnector(count: optionCount, inverted: true),
              const _Canopy(
                key: ValueKey('switch-lower-canopy'),
                inverted: true,
              ),
              const SizedBox(height: 6),
              _ShapeSequence(
                key: const ValueKey('switch-static-target'),
                shapes: target,
                label: 'Secuencia objetivo',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RuleOption extends StatelessWidget {
  const _RuleOption({
    super.key,
    required this.rule,
    required this.shapes,
    required this.revealed,
    required this.reducedMotion,
    this.onHighlight,
    this.onTap,
    this.demoMatch = false,
  });

  final List<int> rule;
  final List<int> shapes;
  final bool revealed;
  final bool reducedMotion;
  final ValueChanged<bool>? onHighlight;
  final VoidCallback? onTap;
  final bool demoMatch;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    onTap: onTap,
    label:
        'Regla ${rule.join(', ')}${revealed ? '. Resultado: ${shapes.map((shape) => _shapeNames[shape]).join(', ')}' : ''}${demoMatch ? '. Coincide con el objetivo del ejemplo.' : ''}',
    excludeSemantics: true,
    child: Material(
      color: demoMatch
          ? AppColors.mint
          : revealed
          ? const Color(0xFFBDDCED)
          : const Color(0xFFD7E6EC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: demoMatch
              ? AppColors.green
              : revealed
              ? _funnelBlue
              : const Color(0xFFC6D7DE),
          width: revealed ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onHighlightChanged: onHighlight,
        splashColor: _funnelBlue.withValues(alpha: .12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  rule.join(' '),
                  style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 1,
                    color: Color(0xFF29424D),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 16,
                child: AnimatedOpacity(
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  opacity: revealed ? 1 : 0,
                  child: Row(
                    children: [
                      for (final shape in shapes)
                        Expanded(
                          child: Center(
                            child: CustomPaint(
                              size: const Size.square(14),
                              painter: _ShapePainter(shape),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ShapeSequence extends StatelessWidget {
  const _ShapeSequence({super.key, required this.shapes, required this.label});
  final List<int> shapes;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: ${shapes.map((shape) => _shapeNames[shape]).join(', ')}',
    image: true,
    excludeSemantics: true,
    child: RepaintBoundary(
      child: SizedBox(
        height: _switchInputHeight,
        child: Row(
          children: [
            for (var index = 0; index < shapes.length; index++)
              Expanded(
                child: Container(
                  key: ValueKey(
                    '${label == 'Secuencia inicial' ? 'switch-input' : 'switch-target'}-$index',
                  ),
                  height: 58,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4E4DA),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: CustomPaint(
                    size: const Size.square(29),
                    painter: _ShapePainter(shapes[index]),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Canopy extends StatelessWidget {
  const _Canopy({super.key, this.inverted = false});
  final bool inverted;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    height: _switchCanopyHeight,
    child: RepaintBoundary(
      child: CustomPaint(painter: _CanopyPainter(inverted)),
    ),
  );
}

class _CanopyPainter extends CustomPainter {
  const _CanopyPainter(this.inverted);
  final bool inverted;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 72, size.height / 48);
    if (inverted) {
      canvas.translate(72, 48);
      canvas.rotate(math.pi);
    }
    canvas.drawPath(
      Path()
        ..moveTo(9, 6)
        ..lineTo(63, 6)
        ..lineTo(43, 32)
        ..lineTo(29, 32)
        ..close(),
      Paint()..color = const Color(0xFF2878B9),
    );
    canvas.drawRect(
      const Rect.fromLTWH(31, 33, 10, 15),
      Paint()..color = const Color(0xFF367DAA),
    );
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: .85)
      ..strokeWidth = 1.5;
    for (var y = 35.0; y < 49; y += 7) {
      canvas.drawLine(Offset(32, y), Offset(40, y + 5), stripe);
    }
    for (final bar in [
      const Rect.fromLTWH(5, 1, 62, 8),
      const Rect.fromLTWH(25, 29, 22, 7),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(2)),
        Paint()..color = _funnelBlue,
      );
      for (var x = bar.left + 5; x < bar.right - 2; x += 9) {
        canvas.drawCircle(
          Offset(x, bar.center.dy),
          1.1,
          Paint()..color = const Color(0xFFD5E8F4),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CanopyPainter oldDelegate) =>
      inverted != oldDelegate.inverted;
}

class _BranchConnector extends StatelessWidget {
  const _BranchConnector({
    super.key,
    required this.count,
    this.inverted = false,
  });
  final int count;
  final bool inverted;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 14,
    width: double.infinity,
    child: CustomPaint(painter: _BranchPainter(count, inverted)),
  );
}

class _BranchPainter extends CustomPainter {
  const _BranchPainter(this.count, this.inverted);
  final int count;
  final bool inverted;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (inverted) {
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }
    final paint = Paint()
      ..color = const Color(0xFFCAD5D4)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final optionWidth = (size.width - (count - 1) * 8) / count;
    for (var index = 0; index < count; index++) {
      final x = optionWidth / 2 + index * (optionWidth + 8);
      canvas.drawPath(
        Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width / 2, 5)
          ..lineTo(x, 5)
          ..lineTo(x, size.height),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BranchPainter oldDelegate) =>
      count != oldDelegate.count || inverted != oldDelegate.inverted;
}

class _ShapePainter extends CustomPainter {
  const _ShapePainter(this.shape);
  final int shape;

  @override
  void paint(Canvas canvas, Size size) => _drawShape(
    canvas,
    shape,
    size.center(Offset.zero),
    math.min(size.width, size.height),
  );

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) =>
      shape != oldDelegate.shape;
}

void _drawShape(Canvas canvas, int shape, Offset center, double side) {
  final paint = Paint()..color = _shapeColors[shape];
  final box = Rect.fromCenter(center: center, width: side, height: side);
  switch (shape) {
    case 0:
      canvas.drawCircle(center, side / 2, paint);
    case 1:
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, box.top)
          ..lineTo(box.right, box.bottom)
          ..lineTo(box.left, box.bottom)
          ..close(),
        paint,
      );
    case 2:
      for (final dimensions in [
        Size(side * .34, side),
        Size(side, side * .34),
      ]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: dimensions.width,
              height: dimensions.height,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    default:
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(2)),
        paint,
      );
  }
}
