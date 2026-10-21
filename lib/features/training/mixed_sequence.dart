import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../../domain/round_controller.dart';
import 'scattered_dot_board.dart';

/// Presentation never advances state. The owning controller alone ends a flash.
class PointFlashView extends StatefulWidget {
  const PointFlashView({super.key, required this.question, this.controller});
  final PointFlashQuestion question;
  final RoundController? controller;

  @override
  State<PointFlashView> createState() => _PointFlashViewState();
}

class _PointFlashViewState extends State<PointFlashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.question.durationMilliseconds),
    animationBehavior: AnimationBehavior.preserve,
  )..forward();

  @override
  void didUpdateWidget(covariant PointFlashView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question) {
      _flash.duration = Duration(
        milliseconds: widget.question.durationMilliseconds,
      );
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('flash-target-${widget.question.cell}'),
    label:
        'Punto ${widget.question.index + 1} de la secuencia. Posición ${widget.question.cell + 1} en la plantilla.',
    image: true,
    child: ScatteredDotBoard(
      question: widget.question.memory,
      flashCell: widget.question.cell,
      flashNumber: widget.question.index + 1,
      animation: _flash,
      durationMilliseconds: widget.question.durationMilliseconds,
      visibleMilliseconds: widget.question.visibleMilliseconds,
      reducedMotion: reduceMotion(context),
    ),
  );
}

/// Retains the user's order, including incorrect choices, until confirmation.
/// No point is marked right/wrong during the round.
class MemorySequenceRecall extends StatefulWidget {
  const MemorySequenceRecall({
    super.key,
    required this.question,
    required this.onSubmit,
    this.onSelectionChanged,
  });
  final MemorySequenceQuestion question;
  final ValueChanged<Object> onSubmit;
  final ValueChanged<List<int>>? onSelectionChanged;

  @override
  State<MemorySequenceRecall> createState() => _MemorySequenceRecallState();
}

class _MemorySequenceRecallState extends State<MemorySequenceRecall> {
  final List<int> _selected = [];
  bool _submitted = false;

  void _select(int cell) {
    if (_submitted) return;
    setState(() {
      final index = _selected.indexOf(cell);
      if (index >= 0) {
        // Revisiting a point rewinds the sequence to that position.
        _selected.removeRange(index, _selected.length);
      } else if (_selected.length < widget.question.sequence.length) {
        _selected.add(cell);
      }
    });
    widget.onSelectionChanged?.call(List<int>.of(_selected));
  }

  void _edit(VoidCallback change) {
    if (_submitted) return;
    setState(change);
    widget.onSelectionChanged?.call(List<int>.of(_selected));
  }

  @override
  void didUpdateWidget(covariant MemorySequenceRecall oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question) {
      _selected.clear();
      _submitted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final count = question.sequence.length;
    return Column(
      children: [
        Semantics(
          liveRegion: true,
          label: '${_selected.length} de $count elegidos',
          child: const SizedBox.shrink(),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            if (question.hasScatteredLayout) {
              return ScatteredDotBoard(
                question: question,
                selected: _selected,
                onSelect: _select,
                enabled: !_submitted,
              );
            }
            final side = math.max(
              question.gridSize * 48.0,
              math.min(384.0, constraints.maxWidth),
            );
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                width: side,
                height: side,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: question.gridSize,
                  ),
                  itemCount: question.gridSize * question.gridSize,
                  itemBuilder: (context, cell) {
                    if (!question.templateCells.contains(cell)) {
                      return const SizedBox.shrink();
                    }
                    final order = _selected.indexOf(cell);
                    final enabled =
                        !_submitted && (order >= 0 || _selected.length < count);
                    return Semantics(
                      label:
                          'Punto en fila ${cell ~/ question.gridSize + 1}, columna ${cell % question.gridSize + 1}',
                      value: order >= 0 ? 'Elegido ${order + 1}' : 'Sin elegir',
                      button: true,
                      selected: order >= 0,
                      enabled: enabled,
                      onTap: enabled ? () => _select(cell) : null,
                      excludeSemantics: true,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: ValueKey('recall-cell-$cell'),
                          onTap: enabled ? () => _select(cell) : null,
                          borderRadius: BorderRadius.circular(12),
                          splashColor: AppColors.mint.withValues(alpha: .3),
                          child: Center(
                            child: AnimatedContainer(
                              duration: reduceMotion(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 100),
                              width: order >= 0 ? 38 : 12,
                              height: order >= 0 ? 38 : 12,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: order >= 0
                                    ? AppColors.mint
                                    : Colors.white.withValues(alpha: .8),
                              ),
                              child: order >= 0
                                  ? Text(
                                      '${order + 1}',
                                      key: ValueKey('recall-order-$cell'),
                                      style: const TextStyle(
                                        color: AppColors.ink,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: _submitted || _selected.isEmpty
                  ? null
                  : () => _edit(_selected.removeLast),
              icon: const Icon(Icons.undo_rounded, size: 17),
              label: const Text('Deshacer'),
            ),
            TextButton(
              onPressed: _submitted || _selected.isEmpty
                  ? null
                  : () => _edit(_selected.clear),
              child: const Text('Limpiar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 384,
          child: FilledButton.icon(
            onPressed: !_submitted && _selected.length == count
                ? () {
                    if (_submitted) return;
                    setState(() => _submitted = true);
                    widget.onSubmit(List<int>.of(_selected));
                  }
                : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Confirmar secuencia'),
          ),
        ),
      ],
    );
  }
}
