import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../../domain/stroke_equation.dart';
import '../../domain/round_controller.dart';
import 'visual_instructions.dart';
import 'stroke_equation.dart';
import 'mixed_sequence.dart';
import 'switch_challenge.dart';
export 'switch_challenge.dart' show MinijuegoSwitchChallenge;

bool _reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    super.key,
    required this.games,
    required this.settings,
  });

  final List<GameType> games;
  final TrainingSettings settings;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen>
    with WidgetsBindingObserver {
  RoundController? _controller;
  final ScrollController _scroll = ScrollController();
  final List<RoundResult> _results = [];
  int _round = 0;
  int _lastQuestion = 0;
  bool _closingRound = false;
  bool _dialogOpen = false;
  bool _allowPop = false;

  GameType get _type => widget.games[_round];

  @override
  void initState() {
    super.initState();
    assert(widget.games.isNotEmpty, 'Selecciona al menos una prueba.');
    WidgetsBinding.instance.addObserver(this);
  }

  void _startRound() {
    if (_controller != null || _allowPop) return;
    if (widget.settings.haptics) HapticFeedback.selectionClick();
    setState(() {
      _controller = RoundController(_type, widget.settings)
        ..addListener(_onRoundChanged);
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller?.refresh();
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  void _onRoundChanged() {
    if (!mounted || _allowPop) return;
    final controller = _controller;
    if (controller == null) return;
    if (_lastQuestion != controller.questionNumber) {
      _lastQuestion = controller.questionNumber;
      _scrollToTop();
    }
    setState(() {});
    if (!controller.isFinished || _closingRound || _dialogOpen) return;
    _closingRound = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _allowPop || _controller != controller) return;
      _closingRound = false;
      if (_dialogOpen) return;
      _results.add(controller.result);
      if (_round == widget.games.length - 1) {
        _popSession(List<RoundResult>.unmodifiable(_results));
      } else {
        controller.removeListener(_onRoundChanged);
        controller.dispose();
        setState(() {
          _round++;
          _controller = null;
        });
        _scrollToTop();
      }
    });
  }

  void _popSession(List<RoundResult>? result) {
    if (!mounted || _allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  Future<void> _confirmExit() async {
    if (_dialogOpen || _allowPop) return;
    if (_controller == null && _results.isEmpty) {
      _popSession(null);
      return;
    }
    _dialogOpen = true;
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir del entrenamiento?'),
        content: Text(
          _controller == null
              ? 'Se descartarán los resultados de esta sesión. Puedes continuar con las instrucciones del siguiente reto.'
              : 'Se descartará esta sesión. El cronómetro sigue avanzando mientras decides.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir practicando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    if (exit == true) {
      _popSession(null);
    } else {
      _onRoundChanged();
    }
  }

  Future<void> _confirmFinish() async {
    final controller = _controller;
    if (_dialogOpen || controller == null || controller.isFinished) return;
    _dialogOpen = true;
    final finish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Terminar esta ronda?'),
        content: Text(
          _round < widget.games.length - 1
              ? 'Se guardarán tus respuestas y verás las instrucciones del siguiente reto. Su cronómetro empezará cuando las aceptes.'
              : 'Se guardarán tus respuestas y podrás consultar el reporte de la sesión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminar ronda'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    if (finish == true && !controller.isFinished) controller.finish();
    _onRoundChanged();
  }

  void _submit(Object answer, [Question? expectedQuestion]) {
    final controller = _controller;
    if (controller == null || controller.isFinished) return;
    if (widget.settings.haptics) HapticFeedback.selectionClick();
    controller.submit(answer, expectedQuestion: expectedQuestion);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onRoundChanged);
    _controller?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final question = controller?.currentQuestion;
    return PopScope<List<RoundResult>>(
      canPop: _allowPop || (controller == null && _results.isEmpty),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _confirmExit,
                      tooltip: 'Salir del entrenamiento',
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    if (controller == null)
                      const SmallTag('INSTRUCCIONES')
                    else
                      TextButton.icon(
                        onPressed: _confirmFinish,
                        icon: const Icon(Icons.flag_outlined, size: 17),
                        label: const Text('Terminar ronda'),
                      ),
                  ],
                ),
              ),
              if (controller != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: BarraProgresoTiempo(
                    controller: controller,
                    total: controller.duration,
                  ),
                ),
              Expanded(
                child: controller == null
                    ? SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 880),
                            child: VisualInstructions(
                              key: ValueKey('instructions_$_round'),
                              type: _type,
                              settings: widget.settings,
                              roundIndex: _round,
                              totalRounds: widget.games.length,
                              onAccept: _startRound,
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 880),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (question is PointFlashQuestion)
                                  PointFlashView(
                                    key: ValueKey(
                                      'flash-${controller.questionNumber}',
                                    ),
                                    question: question,
                                    controller: controller,
                                  )
                                else if (question is MemorySequenceQuestion)
                                  _questionBody(question, controller)
                                else ...[
                                  GestorTransiciones(
                                    enabled:
                                        _type != GameType.switcher &&
                                        !controller.isMixed,
                                    child: SurfacePanel(
                                      key: ValueKey(
                                        '${_round}_${controller.questionNumber}',
                                      ),
                                      child: _questionBody(
                                        question!,
                                        controller,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: controller.isFinished
                                          ? null
                                          : controller.skip,
                                      label: const Text('Omitir'),
                                      icon: const Icon(Icons.skip_next_rounded),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionBody(Question question, RoundController controller) =>
      switch (question) {
        MemorySequenceQuestion() => MemorySequenceRecall(
          question: question,
          onSubmit: (answer) => _submit(answer, question),
          onSelectionChanged: controller.setRecallSelection,
        ),
        MemoryQuestion() => MinijuegoMemoriaPuntos(
          question: question,
          controller: controller,
          onSubmit: (answer) => _submit(answer, question),
        ),
        GridQuestion() => MinijuegoGridChallenge(
          question: question,
          onSubmit: (answer) => _submit(answer, question),
        ),
        SwitchQuestion() => MinijuegoSwitchChallenge(
          question: question,
          onSubmit: (answer) => _submit(answer, question),
        ),
        MathQuestion() => MinijuegoCalculo(
          question: question,
          onSubmit: (answer) => _submit(answer, question),
        ),
        StrokeEquationQuestion() => StrokeEquationGame(
          question: question,
          onSubmit: (answer) => _submit(answer, question),
        ),
        _ => throw StateError('Tipo de ejercicio desconocido'),
      };
}

class BarraProgresoTiempo extends StatelessWidget {
  const BarraProgresoTiempo({
    super.key,
    required this.controller,
    required this.total,
  });

  final RoundController controller;
  final Duration total;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: controller.isMixed
        ? controller.phaseRemaining
        : controller.remaining,
    builder: (context, remaining, _) {
      final seconds = (remaining.inMilliseconds / 1000).ceil();
      final value =
          (remaining.inMilliseconds /
                  (controller.isMixed ? controller.phaseDuration : total)
                      .inMilliseconds)
              .clamp(0.0, 1.0);
      final color = controller.isMixed
          ? (remaining.inMilliseconds <= 1000
                ? AppColors.coral
                : AppColors.green)
          : seconds <= 30
          ? AppColors.coral
          : AppColors.green;
      return TweenAnimationBuilder<double>(
        key: controller.isMixed ? ObjectKey(controller.currentQuestion) : null,
        tween: Tween(end: value),
        duration: _reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 100),
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 7,
          borderRadius: BorderRadius.circular(10),
          backgroundColor: AppColors.line,
          color: color,
          semanticsLabel: 'Tiempo disponible',
          semanticsValue: '${(value * 100).round()}%',
        ),
      );
    },
  );
}

class GestorTransiciones extends StatelessWidget {
  const GestorTransiciones({
    super.key,
    required this.child,
    this.enabled = true,
  });
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final reduced = !enabled || _reduceMotion(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 190),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => IgnorePointer(
          ignoring: animation.status == AnimationStatus.reverse,
          child: ExcludeSemantics(
            excluding: animation.status == AnimationStatus.reverse,
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: reduced ? Offset.zero : const Offset(0.025, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}

class MinijuegoMemoriaPuntos extends StatefulWidget {
  const MinijuegoMemoriaPuntos({
    super.key,
    required this.question,
    required this.controller,
    required this.onSubmit,
  });
  final MemoryQuestion question;
  final RoundController controller;
  final ValueChanged<Object> onSubmit;

  @override
  State<MinijuegoMemoriaPuntos> createState() => _MinijuegoMemoriaPuntosState();
}

class _MinijuegoMemoriaPuntosState extends State<MinijuegoMemoriaPuntos>
    with SingleTickerProviderStateMixin {
  final Set<int> _selected = {};
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateBlink();
  }

  @override
  void didUpdateWidget(covariant MinijuegoMemoriaPuntos oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateBlink();
  }

  void _updateBlink() {
    if (_reduceMotion(context) || !widget.controller.isMemorizing) {
      _blink.stop();
      _blink.value = 1;
    } else if (!_blink.isAnimating) {
      _blink.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memorizing = widget.controller.isMemorizing;
    final count = widget.question.cells.length;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(288.0, math.min(384.0, constraints.maxWidth));
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox.square(
                dimension: side,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _MemoryPainter(
                              cells: widget.question.cells,
                              gridSize: widget.question.gridSize,
                              selected: Set<int>.of(_selected),
                              memorizing: memorizing,
                              blink: _blink,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: GridView.builder(
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: widget.question.gridSize,
                              ),
                          itemCount:
                              widget.question.gridSize *
                              widget.question.gridSize,
                          itemBuilder: (context, index) {
                            final selected = _selected.contains(index);
                            final enabled =
                                !memorizing &&
                                (selected || _selected.length < count);
                            return Semantics(
                              label:
                                  'Fila ${index ~/ widget.question.gridSize + 1}, columna ${index % widget.question.gridSize + 1}',
                              selected: selected,
                              enabled: enabled,
                              button: true,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: enabled
                                      ? () => setState(() {
                                          if (selected) {
                                            _selected.remove(index);
                                          } else {
                                            _selected.add(index);
                                          }
                                        })
                                      : null,
                                  splashColor: AppColors.mint.withValues(
                                    alpha: .2,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 26),
        SizedBox(
          width: 384,
          child: FilledButton.icon(
            onPressed: !memorizing && _selected.length == count
                ? () => widget.onSubmit(_selected.toList())
                : null,
            icon: Icon(
              memorizing
                  ? Icons.visibility_outlined
                  : Icons.arrow_forward_rounded,
            ),
            label: memorizing
                ? const SizedBox.shrink()
                : const Text('Confirmar posiciones'),
          ),
        ),
      ],
    );
  }
}

class _MemoryPainter extends CustomPainter {
  _MemoryPainter({
    required this.cells,
    required this.gridSize,
    required this.selected,
    required this.memorizing,
    required this.blink,
  }) : super(repaint: blink);
  final List<int> cells;
  final int gridSize;
  final Set<int> selected;
  final bool memorizing;
  final Animation<double> blink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.ink);
    final cell = size.width / gridSize;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .055)
      ..strokeWidth = 1;
    for (var i = 1; i < gridSize; i++) {
      canvas.drawLine(Offset(cell * i, 0), Offset(cell * i, size.height), line);
      canvas.drawLine(Offset(0, cell * i), Offset(size.width, cell * i), line);
    }
    for (var i = 0; i < gridSize * gridSize; i++) {
      final position = Offset(
        (i % gridSize + .5) * cell,
        (i ~/ gridSize + .5) * cell,
      );
      final active = memorizing ? cells.contains(i) : selected.contains(i);
      if (active && !memorizing) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: position,
              width: cell - 8,
              height: cell - 8,
            ),
            const Radius.circular(10),
          ),
          Paint()..color = AppColors.green.withValues(alpha: .5),
        );
      }
      canvas.drawCircle(
        position,
        active ? cell * .135 : 2,
        Paint()
          ..color = active
              ? AppColors.mint.withValues(
                  alpha: memorizing ? .82 + blink.value * .18 : 1,
                )
              : Colors.white.withValues(alpha: .15),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MemoryPainter oldDelegate) =>
      cells != oldDelegate.cells ||
      memorizing != oldDelegate.memorizing ||
      gridSize != oldDelegate.gridSize ||
      !setEquals(selected, oldDelegate.selected);
}

class MinijuegoGridChallenge extends StatelessWidget {
  const MinijuegoGridChallenge({
    super.key,
    required this.question,
    required this.onSubmit,
  });
  final GridQuestion question;
  final ValueChanged<Object> onSubmit;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final boardSide = math.min(210.0, (constraints.maxWidth - 44) / 2);
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PatternBoard(
                    cells: question.left,
                    size: question.size,
                    dimension: boardSide,
                    label: 'Patrón de origen',
                  ),
                  SizedBox(
                    width: 44,
                    child: Semantics(
                      label: question.prompt,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.rotate(
                            angle:
                                question.task == GridTask.symmetry &&
                                    question.symmetryAxis == 'horizontal'
                                ? math.pi / 2
                                : 0,
                            child: Icon(
                              question.task == GridTask.combination
                                  ? Icons.add_rounded
                                  : question.task == GridTask.rotation
                                  ? Icons.rotate_right_rounded
                                  : question.task == GridTask.identity
                                  ? Icons.drag_handle_rounded
                                  : Icons.flip_rounded,
                              color: AppColors.muted,
                            ),
                          ),
                          if (question.task == GridTask.rotation)
                            Text(
                              '${question.quarterTurns * 90}°',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _PatternBoard(
                    cells: question.right,
                    size: question.size,
                    dimension: boardSide,
                    label: 'Segundo patrón',
                  ),
                ],
              ),
              if (question.task == GridTask.combination &&
                  question.result != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: AppColors.muted,
                  ),
                ),
                _PatternBoard(
                  cells: question.result!,
                  size: question.size,
                  dimension: boardSide,
                  label: 'Resultado propuesto',
                ),
              ],
            ],
          );
        },
      ),
      const SizedBox(height: 30),
      _YesNoControls(onSubmit: onSubmit),
    ],
  );
}

class _PatternBoard extends StatelessWidget {
  const _PatternBoard({
    required this.cells,
    required this.size,
    required this.dimension,
    required this.label,
  });
  final List<int> cells;
  final int size;
  final double dimension;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$label. Celdas activas: ${cells.map((i) => 'fila ${i ~/ size + 1} columna ${i % size + 1}').join(', ')}',
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        size: Size.square(dimension),
        painter: _PatternPainter(cells: cells, gridSize: size),
      ),
    ),
  );
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({required this.cells, required this.gridSize});
  final List<int> cells;
  final int gridSize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.ink);
    final padding = size.width * .09;
    final step = (size.width - padding * 2) / gridSize;
    for (var i = 0; i < gridSize * gridSize; i++) {
      final center = Offset(
        padding + (i % gridSize + .5) * step,
        padding + (i ~/ gridSize + .5) * step,
      );
      if (cells.contains(i)) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: step * .62,
              height: step * .62,
            ),
            Radius.circular(step * .12),
          ),
          Paint()..color = AppColors.mint,
        );
      } else {
        canvas.drawCircle(
          center,
          math.max(1.5, step * .055),
          Paint()..color = Colors.white.withValues(alpha: .3),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) =>
      !listEquals(cells, oldDelegate.cells) || gridSize != oldDelegate.gridSize;
}

class _YesNoControls extends StatelessWidget {
  const _YesNoControls({required this.onSubmit});
  final ValueChanged<Object> onSubmit;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 480),
    child: Row(
      children: [
        Expanded(
          child: _AnswerTile(
            label: 'Sí',
            icon: Icons.check_rounded,
            onTap: () => onSubmit(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AnswerTile(
            label: 'No',
            icon: Icons.close_rounded,
            onTap: () => onSubmit(false),
          ),
        ),
      ],
    ),
  );
}

class MinijuegoCalculo extends StatefulWidget {
  const MinijuegoCalculo({
    super.key,
    required this.question,
    required this.onSubmit,
  });
  final MathQuestion question;
  final ValueChanged<Object> onSubmit;

  @override
  State<MinijuegoCalculo> createState() => _MinijuegoCalculoState();
}

class _MinijuegoCalculoState extends State<MinijuegoCalculo> {
  final List<int> _selectedIndices = [];
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Text(
                '${question.target}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 50,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 7,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < question.numbers.length; i++) ...[
                    Semantics(
                      label: 'Posición ${i + 1}',
                      value: i < _selectedIndices.length
                          ? '${question.numbers[_selectedIndices[i]]}'
                          : 'vacía',
                      child: Container(
                        width: 43,
                        height: 49,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .2),
                          ),
                        ),
                        child: Text(
                          i < _selectedIndices.length
                              ? '${question.numbers[_selectedIndices[i]]}'
                              : '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (i < question.operators.length)
                      Text(
                        question.operators[i],
                        style: const TextStyle(
                          color: AppColors.mint,
                          fontSize: 22,
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: List.generate(
            question.numbers.length,
            (index) => SizedBox(
              width: 60,
              child: _AnswerTile(
                label: '${question.numbers[index]}',
                selected: _selectedIndices.contains(index),
                onTap: _selectedIndices.contains(index)
                    ? null
                    : () => setState(() => _selectedIndices.add(index)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _selectedIndices.isEmpty
                  ? null
                  : () => setState(() => _selectedIndices.removeLast()),
              icon: const Icon(Icons.undo_rounded, size: 17),
              label: const Text('Deshacer'),
            ),
            TextButton(
              onPressed: _selectedIndices.isEmpty
                  ? null
                  : () => setState(_selectedIndices.clear),
              child: const Text('Limpiar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 384,
          child: FilledButton.icon(
            onPressed:
                !_submitted &&
                    _selectedIndices.length == question.numbers.length
                ? () {
                    if (_submitted) return;
                    setState(() => _submitted = true);
                    widget.onSubmit(
                      _selectedIndices.map((i) => question.numbers[i]).toList(),
                    );
                  }
                : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Confirmar operación'),
          ),
        ),
      ],
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? AppColors.mint : AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? AppColors.green : AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58, minWidth: 48),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: AppColors.ink),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
