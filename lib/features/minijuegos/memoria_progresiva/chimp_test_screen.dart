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
  static const green = Color(0xFF287C61);
  static const mint = Color(0xFFDEF3E8);
  static const background = Color(0xFFF6F7F4);
  static const line = Color(0xFFE4E8E2);
  static const white = Colors.white;
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE RONDA CHIMP
// ─────────────────────────────────────────────────────────────────────────────
class _ChimpRound {
  _ChimpRound({required math.Random rng, required this.count}) {
    // Grid 4x4 = 16 celdas
    final cells = List<int>.generate(16, (i) => i)..shuffle(rng);
    final chosen = cells.take(count).toList();
    // Asignar números 1..count en orden aleatorio a las posiciones elegidas
    final nums = List<int>.generate(count, (i) => i + 1)..shuffle(rng);
    cellToNumber = {for (var i = 0; i < count; i++) chosen[i]: nums[i]};
    // Orden correcto: celda donde está el número 1, celda del 2, etc.
    correctOrder = List<int>.generate(
      count,
      (i) => cellToNumber.entries.firstWhere((e) => e.value == i + 1).key,
    );
  }

  final int count;
  late final Map<int, int> cellToNumber; // celda → número
  late final List<int> correctOrder; // orden correcto de taps
}

// ─────────────────────────────────────────────────────────────────────────────
// FASES DEL CHIMP TEST
// ─────────────────────────────────────────────────────────────────────────────
enum _ChimpPhase { exposure, recall, roundResult }

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA CHIMP TEST (standalone)
// ─────────────────────────────────────────────────────────────────────────────

/// Pantalla aislada del Chimp Test.
/// [onSessionEnd] recibe la lista de resultados (true=correcto por ronda).
class ChimpTestScreen extends StatefulWidget {
  const ChimpTestScreen({
    super.key,
    this.totalRounds = 6,
    required this.onSessionEnd,
    this.onAttempt,
  });

  final ValueChanged<Attempt>? onAttempt;
  final int totalRounds;
  final void Function(List<bool> results) onSessionEnd;

  @override
  State<ChimpTestScreen> createState() => _ChimpTestScreenState();
}

class _ChimpTestScreenState extends State<ChimpTestScreen> {
  late math.Random _rng;
  late _ChimpRound _round;
  _ChimpPhase _phase = _ChimpPhase.exposure;
  int _roundIndex = 0;
  int _numberCount = 6; // empieza en 6, sube hasta 9
  final List<bool> _results = [];
  List<int> _userTaps = [];
  Timer? _exposureTimer;
  final Stopwatch _responseWatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _rng = math.Random();
    _startRound();
  }

  @override
  void dispose() {
    _exposureTimer?.cancel();
    _responseWatch.stop();
    super.dispose();
  }

  void _startRound() {
    _round = _ChimpRound(rng: _rng, count: _numberCount);
    _responseWatch
      ..reset()
      ..start();
    _userTaps = [];
    _phase = _ChimpPhase.exposure;

    // 2.5 segundos de exposición, luego transición a recall
    _exposureTimer?.cancel();
    _exposureTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      // End exposure at the deadline; no extra fade may reveal the numbers.
      setState(() {
        _phase = _ChimpPhase.recall;
      });
    });
    setState(() {});
  }

  void _tapCell(int cellIndex) {
    if (_phase != _ChimpPhase.recall) return;
    if (_userTaps.contains(cellIndex)) return;
    if (!_round.cellToNumber.containsKey(cellIndex)) return;

    HapticFeedback.selectionClick();
    setState(() => _userTaps.add(cellIndex));

    if (_userTaps.length == _round.count) {
      _evaluate();
    }
  }

  void _evaluate() {
    final correct = _listEq(_userTaps, _round.correctOrder);
    _results.add(correct);
    widget.onAttempt?.call(
      Attempt(
        prompt: 'Chimp · ${_round.count} números',
        given: _userTaps.map((cell) => _round.cellToNumber[cell]).join(' → '),
        expected: List.generate(_round.count, (i) => i + 1).join(' → '),
        correct: correct,
        skipped: false,
        response: _responseWatch.elapsed,
      ),
    );
    setState(() => _phase = _ChimpPhase.roundResult);
  }

  bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _nextRound() {
    if (_roundIndex + 1 >= widget.totalRounds) {
      widget.onSessionEnd(List.unmodifiable(_results));
      return;
    }
    setState(() {
      _roundIndex++;
      // Aumentar dificultad gradualmente (máx 9)
      if (_numberCount < 9) _numberCount++;
      _startRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _phase == _ChimpPhase.exposure
          ? _C
                .ink // fondo oscuro durante exposición
          : _C.background,
      body: SafeArea(
        child: _phase == _ChimpPhase.roundResult
            ? _RoundResultView(
                onNext: _nextRound,
                isLast: _roundIndex + 1 >= widget.totalRounds,
              )
            : _ChimpBoardView(
                round: _round,
                recall: _phase == _ChimpPhase.recall,
                userTaps: _userTaps,
                roundIndex: _roundIndex,
                totalRounds: widget.totalRounds,
                onTap: _tapCell,
              ),
      ),
    );
  }
}

/// Both phases use identical bounds: hiding numbers never moves their cells.
class _ChimpBoardView extends StatelessWidget {
  const _ChimpBoardView({
    required this.round,
    required this.recall,
    required this.userTaps,
    required this.roundIndex,
    required this.totalRounds,
    required this.onTap,
  });
  final _ChimpRound round;
  final bool recall;
  final List<int> userTaps;
  final int roundIndex;
  final int totalRounds;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = math.min(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              return Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemCount: 16,
                    itemBuilder: (_, cell) {
                      final number = round.cellToNumber[cell];
                      if (number == null) return const SizedBox.shrink();
                      final order = userTaps.indexOf(cell);
                      final touched = order >= 0;
                      return GestureDetector(
                        key: ValueKey('chimp-cell-$cell'),
                        onTap: recall && !touched ? () => onTap(cell) : null,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: !recall
                                ? Colors.transparent
                                : touched
                                ? _C.green
                                : _C.white,
                            borderRadius: BorderRadius.circular(12),
                            border: recall
                                ? Border.all(
                                    color: touched ? _C.green : _C.line,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Center(
                            child: !recall
                                ? FittedBox(
                                    child: Text(
                                      '$number',
                                      key: ValueKey('chimp-number-$number'),
                                      style: const TextStyle(
                                        color: _C.mint,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  )
                                : touched
                                ? Text(
                                    '${order + 1}',
                                    style: const TextStyle(
                                      color: _C.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTA DE RESULTADO DE RONDA (sin feedback correcto/incorrecto — flujo
// implacable, solo botón de continuar)
// ─────────────────────────────────────────────────────────────────────────────
class _RoundResultView extends StatelessWidget {
  const _RoundResultView({required this.onNext, required this.isLast});

  final VoidCallback onNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🐟', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            child: FilledButton(
              onPressed: onNext,
              child: Text(isLast ? 'Ver resultados' : 'Siguiente ronda'),
            ),
          ),
        ],
      ),
    );
  }
}
