import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';

/// One fixed spatial template is shared by every flash and its ordered recall.
/// Positions belong to the question; rebuilding or resizing never rerolls them.
class ScatteredDotBoard extends StatelessWidget {
  const ScatteredDotBoard({
    super.key,
    required this.question,
    this.selected = const [],
    this.onSelect,
    this.enabled = true,
    this.flashCell,
    this.flashNumber,
    this.animation,
    this.durationMilliseconds = 3500,
    this.visibleMilliseconds = 3500,
    this.reducedMotion = false,
  });

  static const blue = Color(0xFF4C9BBE);
  static const red = Color(0xFFD92136);
  final MemorySequenceQuestion question;
  final List<int> selected;
  final ValueChanged<int>? onSelect;
  final bool enabled;
  final int? flashCell;
  final int? flashNumber;
  final Animation<double>? animation;
  final int durationMilliseconds;
  final int visibleMilliseconds;
  final bool reducedMotion;

  static Offset centerFor(
    MemorySequenceQuestion question,
    int cell,
    Size size,
  ) {
    final point = question.positionFor(cell);
    final margin = math.min(24.0, size.shortestSide / 5);
    return Offset(
      margin + point.x * math.max(0, size.width - margin * 2),
      margin + point.y * math.max(0, size.height - margin * 2),
    );
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.65,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final canSelect = enabled && onSelect != null;
        bool canSelectCell(int cell) =>
            canSelect &&
            (selected.contains(cell) ||
                selected.length < question.sequence.length);
        final centers = {
          for (final cell in question.templateCells)
            cell: centerFor(question, cell, size),
        };
        void selectNearest(TapUpDetails details) {
          if (!canSelect) return;
          int? nearest;
          var bestDistance = 24.0;
          for (final entry in centers.entries) {
            final distance = (entry.value - details.localPosition).distance;
            if (distance <= bestDistance) {
              nearest = entry.key;
              bestDistance = distance;
            }
          }
          if (nearest != null) onSelect!(nearest);
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapUp: canSelect ? selectNearest : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _ScatteredDotsPainter(
                      question: question,
                      flashCell: flashCell,
                      flashNumber: flashNumber,
                      animation: animation,
                      durationMilliseconds: durationMilliseconds,
                      visibleMilliseconds: visibleMilliseconds,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                ),
                if (onSelect != null)
                  for (final cell in question.templateCells)
                    Positioned(
                      left: centers[cell]!.dx - 24,
                      top: centers[cell]!.dy - 24,
                      width: 48,
                      height: 48,
                      child: Semantics(
                        key: ValueKey('recall-cell-$cell'),
                        button: true,
                        enabled: canSelectCell(cell),
                        selected: selected.contains(cell),
                        label: 'Punto ${cell + 1}',
                        value: selected.contains(cell)
                            ? 'Elegido ${selected.indexOf(cell) + 1}'
                            : 'Sin elegir',
                        onTap: canSelectCell(cell)
                            ? () => onSelect!(cell)
                            : null,
                        excludeSemantics: true,
                        child: IgnorePointer(
                          child: Center(
                            child: selected.contains(cell)
                                ? Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      '${selected.indexOf(cell) + 1}',
                                      key: ValueKey('recall-order-$cell'),
                                      textScaler: TextScaler.noScaling,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : const SizedBox.square(dimension: 18),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ScatteredDotsPainter extends CustomPainter {
  _ScatteredDotsPainter({
    required this.question,
    required this.flashCell,
    required this.flashNumber,
    required this.animation,
    required this.durationMilliseconds,
    required this.visibleMilliseconds,
    required this.reducedMotion,
  }) : super(repaint: animation);

  final MemorySequenceQuestion question;
  final int? flashCell;
  final int? flashNumber;
  final Animation<double>? animation;
  final int durationMilliseconds;
  final int visibleMilliseconds;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = ScatteredDotBoard.blue,
    );
    final radius = (size.width / 44).clamp(5.0, 10.0);
    for (final cell in question.templateCells) {
      final center = ScatteredDotBoard.centerFor(question, cell, size);
      canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    }
    if (flashCell == null || flashNumber == null) return;
    final elapsed = (animation?.value ?? 0) * durationMilliseconds;
    if (elapsed >= visibleMilliseconds) return;
    // Each half-cycle lasts 500 ms: a soft fade out, then a soft fade in.
    final opacity = reducedMotion
        ? 1.0
        : (1 + math.cos(elapsed / 500 * math.pi)) / 2;
    final center = ScatteredDotBoard.centerFor(question, flashCell!, size);
    final markerRadius = (size.width / 25).clamp(13.0, 19.0);
    canvas.drawCircle(
      center,
      markerRadius,
      Paint()..color = ScatteredDotBoard.red.withValues(alpha: opacity),
    );
    canvas.drawCircle(
      center,
      markerRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final label = TextPainter(
      text: TextSpan(
        text: '$flashNumber',
        style: TextStyle(
          fontFamily: 'FiraSans',
          color: Colors.white.withValues(alpha: opacity),
          fontWeight: FontWeight.w600,
          fontSize: markerRadius,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
  }

  @override
  bool shouldRepaint(_ScatteredDotsPainter oldDelegate) =>
      oldDelegate.question != question ||
      oldDelegate.flashCell != flashCell ||
      oldDelegate.flashNumber != flashNumber ||
      oldDelegate.animation != animation ||
      oldDelegate.durationMilliseconds != durationMilliseconds ||
      oldDelegate.visibleMilliseconds != visibleMilliseconds ||
      oldDelegate.reducedMotion != reducedMotion;
}
