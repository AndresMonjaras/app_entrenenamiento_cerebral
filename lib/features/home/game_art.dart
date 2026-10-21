import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';

Color gameColor(GameType type) => switch (type) {
  GameType.memory => AppColors.green,
  GameType.grid => AppColors.purple,
  GameType.symmetry => const Color(0xFF4B82A1),
  GameType.switcher => AppColors.amber,
  GameType.math => AppColors.coral,
  GameType.strokes => const Color(0xFF405CA0),
  GameType.mixed => const Color(0xFF237A9E),
};

Color gameBackground(GameType type) => switch (type) {
  GameType.memory => const Color(0xFFEAF4EE),
  GameType.grid => const Color(0xFFEFEDF8),
  GameType.symmetry => const Color(0xFFE8F1F8),
  GameType.switcher => const Color(0xFFFAF1E2),
  GameType.math => const Color(0xFFFAEDE7),
  GameType.strokes => const Color(0xFFE9EDFA),
  GameType.mixed => const Color(0xFFE4F2F7),
};

IconData gameIcon(GameType type) => switch (type) {
  GameType.memory => Icons.blur_on_rounded,
  GameType.grid => Icons.grid_view_rounded,
  GameType.symmetry => Icons.flip_rounded,
  GameType.switcher => Icons.alt_route_rounded,
  GameType.math => Icons.calculate_outlined,
  GameType.strokes => Icons.polyline_rounded,
  GameType.mixed => Icons.shuffle_rounded,
};

String gameSkill(GameType type) => switch (type) {
  GameType.memory => 'MEMORIA VISUAL',
  GameType.grid => 'RAZONAMIENTO Y MEMORIA',
  GameType.symmetry => 'SIMETRÍA Y MEMORIA',
  GameType.switcher => 'LÓGICA Y SECUENCIAS',
  GameType.math => 'AGILIDAD NUMÉRICA',
  GameType.strokes => 'PRECISIÓN GEOMÉTRICA',
  GameType.mixed => 'MEMORIA Y RAZONAMIENTO',
};

class GameArt extends StatelessWidget {
  const GameArt({super.key, required this.type, this.hero = false});
  final GameType type;
  final bool hero;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _GamePainter(type, hero),
      child: const SizedBox.expand(),
    ),
  );
}

class _GamePainter extends CustomPainter {
  _GamePainter(this.type, this.hero);
  final GameType type;
  final bool hero;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 200, size.height / 120);
    canvas.save();
    canvas.translate(
      (size.width - 200 * scale) / 2,
      (size.height - 120 * scale) / 2,
    );
    canvas.scale(scale);
    final color = gameColor(type);
    final paint = Paint()..color = color;
    switch (type) {
      case GameType.strokes:
        final pen = Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        for (final origin in [const Offset(22, 30), const Offset(116, 30)]) {
          canvas.drawLine(origin, origin + const Offset(0, 60), pen);
          canvas.drawLine(
            origin + const Offset(0, 30),
            origin + const Offset(50, 30),
            pen,
          );
          canvas.drawLine(
            origin + const Offset(50, 0),
            origin + const Offset(50, 60),
            pen,
          );
          canvas.drawLine(
            origin + const Offset(0, 60),
            origin + const Offset(50, 0),
            pen,
          );
        }
      case GameType.memory:
      case GameType.mixed:
        for (var y = 0; y < 4; y++) {
          for (var x = 0; x < 7; x++) {
            final lit = <int>{3, 8, 12, 17, 24}.contains(y * 7 + x);
            paint.color = lit ? color : color.withValues(alpha: .12);
            if (lit) {
              canvas.drawCircle(
                Offset(28.0 + x * 24, 23.0 + y * 25),
                12,
                Paint()..color = color.withValues(alpha: .08),
              );
            }
            canvas.drawCircle(
              Offset(28.0 + x * 24, 23.0 + y * 25),
              lit ? 5 : 2,
              paint,
            );
          }
        }
      case GameType.grid:
      case GameType.symmetry:
        for (var panel = 0; panel < 2; panel++) {
          canvas.save();
          canvas.translate(panel * 100.0 + 10, 18);
          if (panel == 1) {
            canvas.translate(42, 42);
            if (type == GameType.symmetry) {
              canvas.scale(-1.0, 1.0);
            } else {
              canvas.rotate(math.pi / 2);
            }
            canvas.translate(-42, -42);
          }
          for (var y = 0; y < 4; y++) {
            for (var x = 0; x < 4; x++) {
              final lit = x == 0 || y == 3 || (x == 2 && y == 1);
              paint.color = lit
                  ? color.withValues(alpha: .8)
                  : color.withValues(alpha: .09);
              canvas.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromLTWH(x * 21.0, y * 21.0, 16, 16),
                  const Radius.circular(4),
                ),
                paint,
              );
            }
          }
          canvas.restore();
        }
      case GameType.switcher:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: .25);
        canvas.drawPath(
          Path()
            ..moveTo(36, 30)
            ..lineTo(36, 60)
            ..lineTo(163, 60)
            ..lineTo(163, 90),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(163, 30)
            ..lineTo(163, 45)
            ..lineTo(100, 45)
            ..lineTo(100, 90),
          paint,
        );
        paint.style = PaintingStyle.fill;
        for (var i = 0; i < 4; i++) {
          for (var row = 0; row < 2; row++) {
            final x = 24.0 + i * 47;
            final y = row == 0 ? 14.0 : 80.0;
            paint.color = color.withValues(alpha: .12);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y, 32, 32),
                const Radius.circular(8),
              ),
              paint,
            );
            paint.color = color;
            final code = row == 0 ? i : 3 - i;
            if (code == 0) {
              canvas.drawCircle(Offset(x + 16, y + 16), 7, paint);
            } else if (code == 1) {
              canvas.drawPath(
                Path()
                  ..moveTo(x + 16, y + 8)
                  ..lineTo(x + 24, y + 24)
                  ..lineTo(x + 8, y + 24)
                  ..close(),
                paint,
              );
            } else if (code == 2) {
              canvas.drawRect(Rect.fromLTWH(x + 9, y + 13, 14, 6), paint);
              canvas.drawRect(Rect.fromLTWH(x + 13, y + 9, 6, 14), paint);
            } else {
              canvas.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromLTWH(x + 9, y + 9, 14, 14),
                  const Radius.circular(2),
                ),
                paint,
              );
            }
          }
        }
      case GameType.math:
        const labels = ['8', '×', '4', '+', '2'];
        for (var i = 0; i < labels.length; i++) {
          final tile = i.isEven;
          final x = 8.0 + i * 39;
          if (tile) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, 34, 34, 44),
                const Radius.circular(8),
              ),
              Paint()..color = color.withValues(alpha: .13),
            );
          }
          final text = TextPainter(
            text: TextSpan(
              text: labels[i],
              style: TextStyle(
                fontFamily: 'FiraSans',
                color: color,
                fontSize: 25,
                fontWeight: FontWeight.w500,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(canvas, Offset(x + (34 - text.width) / 2, 41));
        }
        final text = TextPainter(
          text: TextSpan(
            text: '= 34',
            style: TextStyle(
              fontFamily: 'FiraSans',
              color: color.withValues(alpha: .65),
              fontSize: 13,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, const Offset(85, 89));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GamePainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.hero != hero;
}

class HeroArtwork extends StatelessWidget {
  const HeroArtwork({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.green.withValues(alpha: .10)),
          ),
        ),
        Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.green.withValues(alpha: .12)),
          ),
        ),
        Transform.rotate(
          angle: -.18,
          child: Container(
            width: 165,
            height: 165,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: .16),
                  blurRadius: 28,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: CustomPaint(painter: _HeroDots()),
          ),
        ),
        Positioned(
          top: 25,
          right: 10,
          child: Transform.rotate(
            angle: .14,
            child: Container(
              width: 67,
              height: 67,
              decoration: BoxDecoration(
                color: const Color(0xFFD8CFED),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: const Icon(
                Icons.crop_rotate_rounded,
                color: Color(0xFF736399),
                size: 32,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 6,
          child: Transform.rotate(
            angle: .08,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Text(
                '1  3  4  2',
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9A783F),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          top: 34,
          left: 28,
          child: Icon(Icons.add, color: AppColors.green, size: 20),
        ),
        Positioned(
          bottom: 48,
          right: 28,
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class _HeroDots extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 25; i++) {
      final active = {2, 6, 13, 16, 24}.contains(i);
      canvas.drawCircle(
        Offset(27 + (i % 5) * 27, 27 + (i ~/ 5) * 27),
        active ? 7 : 2.2,
        Paint()
          ..color = active
              ? const Color(0xFFDCF6CA)
              : Colors.white.withValues(alpha: .3),
      );
    }
  }

  @override
  bool shouldRepaint(_HeroDots oldDelegate) => false;
}
