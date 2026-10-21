import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// A fixed, unscored example; its clock is independent of the session clock.
class NumberMemoryWalkthrough extends StatefulWidget {
  const NumberMemoryWalkthrough({super.key, required this.chimp});
  final bool chimp;
  @override
  State<NumberMemoryWalkthrough> createState() =>
      _NumberMemoryWalkthroughState();
}

class _NumberMemoryWalkthroughState extends State<NumberMemoryWalkthrough>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _clock.stop();
      _clock.value = .95;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) {
      final exposure = _clock.value < 2.5 / 6;
      final count = widget.chimp ? 6 : 3;
      final selected = exposure
          ? 0
          : ((_clock.value * 6 - 2.5) / .5).floor().clamp(0, count);
      const cells = [5, 0, 10, 3, 8, 7];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SmallTag('EJEMPLO GUIADO · SIN PUNTUACIÓN'),
          const SizedBox(height: 12),
          Semantics(
            image: true,
            label: 'Primero memoriza los números. Después toca los cuadros en orden ascendente.',
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.chimp && exposure
                      ? AppColors.ink
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SizedBox(
                    height: 220,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisExtent: 60,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: 12,
                      itemBuilder: (context, cell) {
                        final order = cells.take(count).toList().indexOf(cell);
                        if (order < 0) return const SizedBox.shrink();
                        final touched = order < selected;
                        final nakedNumber = widget.chimp && exposure;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: nakedNumber
                                ? Colors.transparent
                                : touched
                                ? AppColors.mint
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: nakedNumber
                                ? null
                                : Border.all(color: AppColors.line),
                          ),
                          child: Center(
                            child: Text(
                              exposure || touched ? '${order + 1}' : '',
                              style: TextStyle(
                                color: nakedNumber
                                    ? AppColors.mint
                                    : AppColors.ink,
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            exposure
                ? '01 · Memoriza durante 2.5 segundos'
                : '02 · Toca los cuadros: 1 → 2 → 3…',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.green, fontSize: 12),
          ),
        ],
      );
    },
  );
}
