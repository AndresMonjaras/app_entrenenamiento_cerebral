import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models.dart' show Attempt;

// ─────────────────────────────────────────────────────────────────────────────
// COLORES LOCALES
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _C {
  static const ink = Color(0xFF172C34);
  static const muted = Color(0xFF74817E);
  static const green = Color(0xFF287C61);
  static const background = Color(0xFFF6F7F4);
  static const line = Color(0xFFE4E8E2);
  static const amber = Color(0xFFC98931);
  static const coral = Color(0xFFD47D65);
  static const white = Colors.white;
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS
// ─────────────────────────────────────────────────────────────────────────────
enum MemoryProgressPhase { memorize, recall, levelResult }

class LevelAttempt {
  LevelAttempt({required this.level, required this.correct});
  final int level;
  final bool correct;
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLLER
// ─────────────────────────────────────────────────────────────────────────────
class MemoriaProgresivaController extends ChangeNotifier {
  MemoriaProgresivaController({math.Random? rng, this.onAttempt})
    : _rng = rng ?? math.Random() {
    _buildLevel();
  }

  final math.Random _rng;
  final ValueChanged<Attempt>? onAttempt;
  final Stopwatch _responseWatch = Stopwatch();

  int level = 1;
  bool hasExtraLife = false;
  bool gameOver = false;

  /// Fase actual de la ronda
  MemoryProgressPhase phase = MemoryProgressPhase.memorize;

  /// Número de elementos = 2 + level (nivel 1→3, nivel 2→4, ...)
  int get elementsCount => 2 + level;

  /// Cuadrícula 4×5 = 20 celdas; mapeamos celda→número (1-based)
  Map<int, int> cellToNumber = {};

  /// Taps del usuario (índices de celda) durante recall
  List<int> userTaps = [];

  /// Temporizador para la fase memorize (2.5 s)
  Timer? _memorizeTimer;

  /// Resultado de la última evaluación
  bool? lastCorrect;

  /// Historial completo de la sesión
  final List<LevelAttempt> attempts = [];

  // ── Construir nivel ────────────────────────────────────────────────────
  void _buildLevel() {
    final count = elementsCount;
    // The existing board has 20 cells: finish after its last playable level.
    if (count > 20) {
      gameOver = true;
      notifyListeners();
      return;
    }
    _responseWatch
      ..reset()
      ..start();
    // Elegir [count] celdas aleatorias de 20
    final allCells = List<int>.generate(20, (i) => i)..shuffle(_rng);
    final chosen = allCells.take(count).toList();
    // Asignar números 1..count en orden ascendente a posiciones aleatorias
    final numbers = List<int>.generate(count, (i) => i + 1)..shuffle(_rng);
    cellToNumber = {for (var i = 0; i < count; i++) chosen[i]: numbers[i]};
    userTaps = [];
    phase = MemoryProgressPhase.memorize;
    lastCorrect = null;
    _startMemorizeTimer();
    notifyListeners();
  }

  void _startMemorizeTimer() {
    _memorizeTimer?.cancel();
    _memorizeTimer = Timer(const Duration(milliseconds: 2500), () {
      if (phase == MemoryProgressPhase.memorize) {
        phase = MemoryProgressPhase.recall;
        notifyListeners();
      }
    });
  }

  /// Toca una celda durante recall. Solo acepta celdas válidas.
  void tapCell(int cellIndex) {
    if (phase != MemoryProgressPhase.recall) return;
    if (!cellToNumber.containsKey(cellIndex)) return;
    if (userTaps.contains(cellIndex)) return;

    HapticFeedback.selectionClick();
    userTaps.add(cellIndex);

    if (userTaps.length == elementsCount) {
      _evaluate();
    }
    notifyListeners();
  }

  void undoLastTap() {
    if (userTaps.isEmpty || phase != MemoryProgressPhase.recall) return;
    userTaps.removeLast();
    notifyListeners();
  }

  void _evaluate() {
    // Correcto = taps en orden numérico ascendente (1,2,3...)
    final correct = _checkOrder();
    lastCorrect = correct;
    attempts.add(LevelAttempt(level: level, correct: correct));
    onAttempt?.call(
      Attempt(
        prompt: 'Memoria progresiva · nivel $level ($elementsCount elementos)',
        given: userTaps.map((cell) => cellToNumber[cell]).join(' → '),
        expected: List.generate(elementsCount, (i) => i + 1).join(' → '),
        correct: correct,
        skipped: false,
        response: _responseWatch.elapsed,
      ),
    );
    phase = MemoryProgressPhase.levelResult;
    notifyListeners();
  }

  bool _checkOrder() {
    // El número de la celda tapada en posición i debe ser i+1
    for (var i = 0; i < userTaps.length; i++) {
      final num = cellToNumber[userTaps[i]];
      if (num != i + 1) return false;
    }
    return true;
  }

  /// Avanzar tras mostrar el resultado del nivel
  void advance() {
    if (phase != MemoryProgressPhase.levelResult) return;
    final correct = lastCorrect ?? false;

    if (correct) {
      // Verificar si superó el nivel 6 por primera vez
      if (level >= 6 && !hasExtraLife) hasExtraLife = true;
      level++;
      _buildLevel();
    } else {
      if (hasExtraLife) {
        // Usa la vida extra: regenera posiciones, mismo nivel
        hasExtraLife = false;
        _buildLevel();
      } else {
        gameOver = true;
        notifyListeners();
      }
    }
  }

  void restart() {
    level = 1;
    hasExtraLife = false;
    gameOver = false;
    attempts.clear();
    _buildLevel();
  }

  @override
  void dispose() {
    _memorizeTimer?.cancel();
    _responseWatch.stop();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL — Modo Progresivo
// ─────────────────────────────────────────────────────────────────────────────
class MemoriaProgresivaScreen extends StatelessWidget {
  const MemoriaProgresivaScreen({
    super.key,
    this.onAttempt,
    this.onSessionEnd,
    this.deferredFeedback = false,
  });
  final ValueChanged<Attempt>? onAttempt;
  final VoidCallback? onSessionEnd;
  final bool deferredFeedback;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MemoriaProgresivaController>(
      create: (_) => MemoriaProgresivaController(onAttempt: onAttempt),
      child: _MemoriaProgresivaBody(
        onSessionEnd: onSessionEnd,
        deferredFeedback: deferredFeedback,
      ),
    );
  }
}

class _MemoriaProgresivaBody extends StatelessWidget {
  const _MemoriaProgresivaBody({
    this.onSessionEnd,
    this.deferredFeedback = false,
  });
  final VoidCallback? onSessionEnd;
  final bool deferredFeedback;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MemoriaProgresivaController>();

    if (ctrl.gameOver) {
      if (onSessionEnd != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) onSessionEnd!();
        });
        return const Scaffold(body: Center(child: Text('Ronda terminada')));
      }
      return _GameOverPanel(attempts: ctrl.attempts, onRestart: ctrl.restart);
    }

    return Scaffold(
      backgroundColor: _C.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(level: ctrl.level, hasExtraLife: ctrl.hasExtraLife),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: switch (ctrl.phase) {
                  MemoryProgressPhase.memorize => _MemorizeGrid(
                    key: ValueKey('mem_${ctrl.level}'),
                    ctrl: ctrl,
                  ),
                  MemoryProgressPhase.recall => _RecallGrid(
                    key: ValueKey('rec_${ctrl.level}'),
                    ctrl: ctrl,
                  ),
                  MemoryProgressPhase.levelResult => _LevelResultPanel(
                    key: ValueKey('res_${ctrl.level}'),
                    ctrl: ctrl,
                    deferred: deferredFeedback,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Barra superior ──────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.level, required this.hasExtraLife});
  final int level;
  final bool hasExtraLife;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: _C.white,
      child: Row(
        children: [
          const Icon(Icons.trending_up, size: 20, color: _C.green),
          const SizedBox(width: 8),
          Text('$level', style: const TextStyle(color: _C.green)),
          const Spacer(),
          Icon(
            hasExtraLife ? Icons.favorite : Icons.favorite_border,
            color: hasExtraLife ? _C.coral : _C.muted,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ─── Grid de memorización ────────────────────────────────────────────────────
class _MemorizeGrid extends StatelessWidget {
  const _MemorizeGrid({super.key, required this.ctrl});
  final MemoriaProgresivaController ctrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [Expanded(child: _NumberGrid(ctrl: ctrl, isRecall: false))],
      ),
    );
  }
}

// ─── Grid de recall ──────────────────────────────────────────────────────────
class _RecallGrid extends StatelessWidget {
  const _RecallGrid({super.key, required this.ctrl});
  final MemoriaProgresivaController ctrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(child: _NumberGrid(ctrl: ctrl, isRecall: true)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: ctrl.userTaps.isEmpty ? null : ctrl.undoLastTap,
                icon: const Icon(Icons.undo_rounded, size: 16),
                label: const Text('Deshacer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Grid de números compartido ──────────────────────────────────────────────
class _NumberGrid extends StatelessWidget {
  const _NumberGrid({required this.ctrl, required this.isRecall});
  final MemoriaProgresivaController ctrl;
  final bool isRecall;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: SizedBox(
          width: math.min(
            constraints.maxWidth,
            math.max(0.0, (constraints.maxHeight - 2) / 1.25),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 20,
            itemBuilder: (_, cellIdx) {
              final num = ctrl.cellToNumber[cellIdx];
              final tapOrder = ctrl.userTaps.indexOf(cellIdx);
              final isTapped = tapOrder >= 0;
              final isActive = num != null;

              if (!isActive) {
                // Celda vacía
                return Container(
                  decoration: BoxDecoration(
                    color: isRecall ? Colors.transparent : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }

              return GestureDetector(
                key: ValueKey('progressive-cell-$cellIdx'),
                onTap: isRecall && !isTapped
                    ? () => ctrl.tapCell(cellIdx)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isRecall
                        ? (isTapped ? _C.green : _C.white)
                        : _C.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRecall
                          ? (isTapped ? _C.green : _C.line)
                          : _C.line,
                      width: 1.5,
                    ),
                    boxShadow: isRecall && !isTapped
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .06),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isRecall
                        ? (isTapped
                              ? Text(
                                  '${tapOrder + 1}',
                                  style: const TextStyle(
                                    color: _C.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null) // cuadro ciego
                        : Text(
                            '$num',
                            style: const TextStyle(
                              color: _C.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Panel de resultado del nivel ────────────────────────────────────────────
class _LevelResultPanel extends StatelessWidget {
  const _LevelResultPanel({
    super.key,
    required this.ctrl,
    this.deferred = false,
  });
  final MemoriaProgresivaController ctrl;
  final bool deferred;

  @override
  Widget build(BuildContext context) {
    if (deferred) {
      return Center(
        child: FilledButton(
          onPressed: ctrl.advance,
          child: const Text('Continuar'),
        ),
      );
    }
    final correct = ctrl.lastCorrect ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              deferred
                  ? Icons.lock_outline
                  : correct
                  ? Icons.check_circle_outline
                  : Icons.highlight_off,
              size: 64,
              color: deferred
                  ? _C.ink
                  : correct
                  ? _C.green
                  : _C.coral,
            ),
            const SizedBox(height: 16),
            Text(
              deferred
                  ? 'Respuesta registrada'
                  : correct
                  ? '¡Correcto!'
                  : 'Fallaste',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: deferred
                    ? _C.ink
                    : correct
                    ? _C.green
                    : _C.coral,
              ),
            ),
            if (!deferred && !correct && ctrl.hasExtraLife) ...[
              const SizedBox(height: 8),
              const Text(
                'Usas tu vida extra — ¡sigue!',
                style: TextStyle(color: _C.amber, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: 220,
              child: FilledButton(
                onPressed: ctrl.advance,
                child: Text(
                  deferred
                      ? 'Continuar'
                      : correct
                      ? 'Siguiente nivel'
                      : 'Reintentar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Game Over ───────────────────────────────────────────────────────────────
class _GameOverPanel extends StatelessWidget {
  const _GameOverPanel({required this.attempts, required this.onRestart});
  final List<LevelAttempt> attempts;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final maxLevel = attempts.isEmpty
        ? 1
        : attempts.map((a) => a.level).reduce(math.max);
    final correct = attempts.where((a) => a.correct).length;
    return Scaffold(
      backgroundColor: _C.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🐟', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                const Text(
                  'Sesión terminada',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _C.ink,
                  ),
                ),
                const SizedBox(height: 24),
                _StatRow('Nivel máximo alcanzado', '$maxLevel'),
                _StatRow('Niveles superados', '$correct / ${attempts.length}'),
                const SizedBox(height: 32),
                SizedBox(
                  width: 220,
                  child: FilledButton(
                    onPressed: onRestart,
                    child: const Text('Jugar de nuevo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _C.muted, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              color: _C.ink,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: must_be_immutable (false positive in some linters)
class ChangeNotifierProvider<T extends ChangeNotifier> extends StatefulWidget {
  const ChangeNotifierProvider({
    super.key,
    required this.create,
    required this.child,
  });

  final T Function(BuildContext) create;
  final Widget child;

  @override
  State<ChangeNotifierProvider<T>> createState() =>
      _ChangeNotifierProviderState<T>();
}

class _ChangeNotifierProviderState<T extends ChangeNotifier>
    extends State<ChangeNotifierProvider<T>> {
  late T _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = widget.create(context);
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (ctx, _) =>
          _InheritedNotifier<T>(notifier: _notifier, child: widget.child),
    );
  }
}

class _InheritedNotifier<T extends ChangeNotifier> extends InheritedWidget {
  const _InheritedNotifier({required this.notifier, required super.child});

  final T notifier;

  @override
  bool updateShouldNotify(_InheritedNotifier<T> old) => true;
}

extension ContextWatch on BuildContext {
  T watch<T extends ChangeNotifier>() {
    final inherited =
        dependOnInheritedWidgetOfExactType<_InheritedNotifier<T>>();
    assert(
      inherited != null,
      'No ChangeNotifierProvider<$T> found in the widget tree.',
    );
    return inherited!.notifier;
  }
}
