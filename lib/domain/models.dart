import 'dart:math';

import 'package:flutter/foundation.dart';

enum GameType {
  memory,
  grid,
  symmetry,
  switcher,
  math,
  strokes,
  mixed;

  /// Modes shown in the primary practice menu. `memory` and `mixed` remain
  /// available for persisted results and the Mojarrules V2 session internals.
  static const practiceModes = <GameType>[
    GameType.grid,
    GameType.symmetry,
    GameType.switcher,
    GameType.math,
    GameType.strokes,
  ];
}

extension GameTypeDetails on GameType {
  String get title => switch (this) {
    GameType.memory => 'Memoria de puntos',
    GameType.grid => 'Grid + Memoria',
    GameType.symmetry => 'Simetría + Memoria',
    GameType.switcher => 'Switch Challenge',
    GameType.math => 'Reto numérico',
    GameType.strokes => 'Ecuaciones de trazos',
    GameType.mixed => 'Memoria + Grid + Simetría',
  };

  String get subtitle => switch (this) {
    GameType.memory => 'Retención visual y atención',
    GameType.grid => 'Razonamiento espacial y memoria visual',
    GameType.symmetry => 'Simetría, identidad y memoria visual',
    GameType.switcher => 'Secuencias y lógica de posición',
    GameType.math => 'Cálculo y agilidad numérica',
    GameType.strokes => 'Superposición exacta de líneas',
    GameType.mixed => 'Secuencia combinada con tiempo por fase',
  };

  String get instructions => switch (this) {
    GameType.memory => 'Observa cada círculo rojo numerado sobre el plano de puntos aleatorios. Cada presentación dura 3.5 segundos y se desvanece/reaparece en pasos de 0.5 segundos. Memoriza de 3 a 5 posiciones en orden. Al final tienes 5 segundos para marcar esa secuencia.',
    GameType.grid => 'Recuerda el punto rojo numerado durante 3.5 segundos. Después tienes 5 segundos para resolver Grid. Se repite punto → figura de 3 a 5 veces y al final dispones de 5 segundos para marcar el orden de los puntos. La flecha indica giro a la derecha y + indica unión.',
    GameType.symmetry => 'Observa primero un punto rojo numerado durante 3.5 segundos y resuelve la figura siguiente en 5 segundos. = compara identidad y el espejo indica el eje de simetría. Tras 3 a 5 pares, marca los puntos en orden durante 5 segundos.',
    GameType.mixed => 'Alterna punto → Grid → punto → Simetría e identidad. Cada punto se presenta 3.5 segundos con desvanecimientos de 0.5 segundos. Cada figura permite 5 segundos. Tras 3, 4 o 5 pares tienes 5 segundos para marcar la secuencia en el mismo plano aleatorio. El tiempo vencido avanza automáticamente; los resultados aparecen al final.',
    GameType.switcher => 'Cada dígito indica qué posición de entrada ocupa ese lugar de salida. Aplica la primera regla y elige la segunda para obtener la secuencia inferior.',
    GameType.math => 'Ordena todas las fichas numéricas para alcanzar el objetivo con los operadores fijos. La multiplicación y la división se resuelven antes que la suma y la resta.',
    GameType.strokes => 'Superpón mentalmente todos los trazos de los dos primeros paneles. Responde Sí solo si el resultado conserva exactamente todas las líneas. Una línea ausente, añadida, deformada o desplazada hace que la respuesta sea No.',
  };
}

enum Difficulty { advanced, expert }

extension DifficultyDetails on Difficulty {
  String get title => this == Difficulty.advanced ? 'Avanzado' : 'Experto';
}

@immutable
class TrainingSettings {
  const TrainingSettings({
    this.roundMinutes = 5,
    this.difficulty = Difficulty.advanced,
    this.haptics = true,
  }) : assert(roundMinutes == 5 || roundMinutes == 6);

  final int roundMinutes;
  final Difficulty difficulty;
  final bool haptics;

  Duration get roundDuration => Duration(minutes: roundMinutes);

  Duration durationFor(GameType type) =>
      type == GameType.memory ||
          type == GameType.grid ||
          type == GameType.symmetry ||
          type == GameType.mixed
      ? const Duration(minutes: 3)
      : roundDuration;

  Duration get simulationDuration => GameType.practiceModes.fold(
    Duration.zero,
    (total, type) => total + durationFor(type),
  );

  TrainingSettings copyWith({
    int? roundMinutes,
    Difficulty? difficulty,
    bool? haptics,
  }) => TrainingSettings(
    roundMinutes: roundMinutes ?? this.roundMinutes,
    difficulty: difficulty ?? this.difficulty,
    haptics: haptics ?? this.haptics,
  );

  Map<String, Object?> toJson() => {
    'roundMinutes': roundMinutes,
    'difficulty': difficulty.name,
    'haptics': haptics,
  };

  factory TrainingSettings.fromJson(Map<String, dynamic> json) =>
      TrainingSettings(
        roundMinutes: json['roundMinutes'] == 6 ? 6 : 5,
        difficulty: json['difficulty'] == 'expert'
            ? Difficulty.expert
            : Difficulty.advanced,
        haptics: json['haptics'] is bool ? json['haptics'] as bool : true,
      );
}

@immutable
abstract class Question {
  const Question();

  String get prompt;
  String get correctAnswerLabel;
  bool check(Object? answer);
  String answerLabel(Object? answer) => answer?.toString() ?? 'Sin respuesta';
}

@immutable
class MemoryQuestion extends Question {
  MemoryQuestion({
    required List<int> cells,
    this.gridSize = 6,
    required this.previewMilliseconds,
  }) : cells = List.unmodifiable(cells);

  final List<int> cells;
  final int gridSize;
  final int previewMilliseconds;

  @override
  String get prompt => 'Recuerda las ${cells.length} posiciones';

  String _positions(Iterable<int> values) {
    final sorted = values.toList()..sort();
    return sorted
        .map((cell) => '${cell ~/ gridSize + 1}:${cell % gridSize + 1}')
        .join(' · ');
  }

  @override
  String get correctAnswerLabel => _positions(cells);

  @override
  bool check(Object? answer) {
    if (answer is! Iterable<int>) return false;
    final values = answer.toList();
    return values.length == cells.length &&
        values.toSet().length == cells.length &&
        values.toSet().containsAll(cells);
  }

  @override
  String answerLabel(Object? answer) =>
      answer is Iterable<int> ? _positions(answer) : super.answerLabel(answer);
}

enum MixedPhase { reasoning, flash, recall }

/// An ordered recall task shares its fixed template with every preceding flash.
/// In contrast, independent [MemoryQuestion] practice compares a set of cells.
@immutable
class MemorySequenceQuestion extends Question {
  MemorySequenceQuestion({
    required List<int> templateCells,
    required List<int> sequence,
    this.gridSize = 6,
    Map<int, Point<double>> positions = const {},
  }) : positions = Map.unmodifiable(positions),
       templateCells = List.unmodifiable(templateCells),
       sequence = List.unmodifiable(sequence) {
    if (gridSize < 1 ||
        templateCells.toSet().length != templateCells.length ||
        templateCells.any((cell) => cell < 0 || cell >= gridSize * gridSize) ||
        sequence.isEmpty ||
        sequence.toSet().length != sequence.length ||
        !templateCells.toSet().containsAll(sequence)) {
      throw ArgumentError(
        'La secuencia requiere puntos distintos de la plantilla.',
      );
    }
    if (positions.isNotEmpty &&
        (!positions.keys.toSet().containsAll(templateCells) ||
            positions.values.any(
              (p) =>
                  !p.x.isFinite ||
                  !p.y.isFinite ||
                  p.x <= 0 ||
                  p.x >= 1 ||
                  p.y <= 0 ||
                  p.y >= 1,
            ))) {
      throw ArgumentError(
        'Las posiciones requieren coordenadas normalizadas dentro del plano.',
      );
    }
  }

  final Map<int, Point<double>> positions;
  bool get hasScatteredLayout => positions.isNotEmpty;
  Point<double> positionFor(int cell) =>
      positions[cell] ??
      Point(
        (cell % gridSize + .5) / gridSize,
        (cell ~/ gridSize + .5) / gridSize,
      );

  final List<int> templateCells;
  final List<int> sequence;
  final int gridSize;

  @override
  String get prompt =>
      'Toca los ${sequence.length} puntos en orden de aparición';

  String _orderedPositions(Iterable<int> cells) => cells
      .map(
        (cell) => hasScatteredLayout
            ? '(${(positionFor(cell).x * 100).round()}%, ${(positionFor(cell).y * 100).round()}%)'
            : '${cell ~/ gridSize + 1}:${cell % gridSize + 1}',
      )
      .join(' → ');

  @override
  String get correctAnswerLabel => _orderedPositions(sequence);

  @override
  bool check(Object? answer) =>
      answer is List<int> && listEquals(answer, sequence);

  @override
  String answerLabel(Object? answer) => answer is Iterable<int>
      ? _orderedPositions(answer)
      : super.answerLabel(answer);
}

/// Passive stimulus: this phase never produces an attempt or reveals a score.
@immutable
class PointFlashQuestion extends Question {
  PointFlashQuestion({
    required this.memory,
    required this.index,
    required this.durationMilliseconds,
    this.visibleMilliseconds = 3500,
  }) : assert(index >= 0 && index < memory.sequence.length);

  final MemorySequenceQuestion memory;
  final int index;
  final int durationMilliseconds;
  final int visibleMilliseconds;

  List<int> get templateCells => memory.templateCells;
  int get gridSize => memory.gridSize;
  int get cell => memory.sequence[index];
  int get total => memory.sequence.length;

  @override
  String get prompt => 'Recuerda el punto ${index + 1} de $total';

  @override
  String get correctAnswerLabel => 'Observación';

  @override
  bool check(Object? answer) => false;
}

enum GridTask { rotation, symmetry, combination, identity }

@immutable
class GridQuestion extends Question {
  GridQuestion({
    required this.task,
    required List<int> left,
    required List<int> right,
    List<int>? result,
    this.size = 5,
    required this.correct,
    this.quarterTurns = 1,
    this.symmetryAxis = 'vertical',
  }) : left = List.unmodifiable(left),
       right = List.unmodifiable(right),
       result = result == null ? null : List.unmodifiable(result);

  final GridTask task;
  final List<int> left;
  final List<int> right;
  final List<int>? result;
  final int size;
  final bool correct;
  final int quarterTurns;
  final String symmetryAxis;

  @override
  String get prompt => switch (task) {
    GridTask.rotation =>
      '¿Es la misma figura girada ${quarterTurns * 90}° a la derecha?',
    GridTask.symmetry =>
      symmetryAxis == 'vertical'
          ? '¿Es un reflejo de izquierda a derecha?'
          : '¿Es un reflejo de arriba hacia abajo?',
    GridTask.combination => '¿La unión de las cuadrículas es correcta?',
    GridTask.identity => '¿Las dos figuras son idénticas?',
  };

  @override
  String get correctAnswerLabel => correct ? 'Sí' : 'No';

  @override
  bool check(Object? answer) => answer is bool && answer == correct;

  @override
  String answerLabel(Object? answer) =>
      answer is bool ? (answer ? 'Sí' : 'No') : super.answerLabel(answer);
}

@immutable
class SwitchQuestion extends Question {
  SwitchQuestion({
    required List<int> input,
    required List<int> firstRule,
    required List<int> output,
    required List<List<int>> options,
    required this.correctIndex,
  }) : input = List.unmodifiable(input),
       firstRule = List.unmodifiable(firstRule),
       output = List.unmodifiable(output),
       options = List.unmodifiable(options.map(List<int>.unmodifiable));

  final List<int> input;
  final List<int> firstRule;
  final List<int> output;
  final List<List<int>> options;
  final int correctIndex;

  @override
  String get prompt => '¿Qué regla completa la secuencia?';

  @override
  String get correctAnswerLabel => options[correctIndex].join();

  @override
  bool check(Object? answer) => answer is int && answer == correctIndex;

  @override
  String answerLabel(Object? answer) =>
      answer is int && answer >= 0 && answer < options.length
      ? options[answer].join()
      : super.answerLabel(answer);
}

/// Evaluates fixed operators using standard arithmetic precedence.
/// Returns null for invalid expressions or division by zero.
num? evaluateExpression(List<int> numbers, List<String> operators) {
  if (numbers.isEmpty || operators.length != numbers.length - 1) return null;
  num term = numbers.first;
  num total = 0;
  var sign = 1;
  for (var i = 0; i < operators.length; i++) {
    final next = numbers[i + 1];
    switch (operators[i]) {
      case '×' || '*':
        term *= next;
      case '÷' || '/':
        if (next == 0) return null;
        term /= next;
      case '+':
        total += sign * term;
        sign = 1;
        term = next;
      case '−' || '-':
        total += sign * term;
        sign = -1;
        term = next;
      default:
        return null;
    }
  }
  return total + sign * term;
}

@immutable
class MathQuestion extends Question {
  MathQuestion({
    required List<int> numbers,
    required List<String> operators,
    required this.target,
    required this.solution,
  }) : numbers = List.unmodifiable(numbers),
       operators = List.unmodifiable(operators);

  final List<int> numbers;
  final List<String> operators;
  final int target;
  final String solution;

  @override
  String get prompt => 'Ordena las fichas para obtener $target';

  @override
  String get correctAnswerLabel => solution;

  @override
  bool check(Object? answer) {
    if (answer is! List<int> || answer.length != numbers.length) return false;
    final actual = answer.toList()..sort();
    final expected = numbers.toList()..sort();
    if (!listEquals(actual, expected)) return false;
    final value = evaluateExpression(answer, operators);
    return value != null && (value - target).abs() < 0.0000001;
  }

  @override
  String answerLabel(Object? answer) {
    if (answer is! List<int> || answer.isEmpty) {
      return super.answerLabel(answer);
    }
    final parts = <String>[answer.first.toString()];
    for (var i = 1; i < answer.length; i++) {
      if (i - 1 < operators.length) parts.add(operators[i - 1]);
      parts.add(answer[i].toString());
    }
    return parts.join(' ');
  }
}

@immutable
class Attempt {
  const Attempt({
    required this.prompt,
    required this.given,
    required this.expected,
    required this.correct,
    required this.skipped,
    required this.response,
  });

  final String prompt;
  final String given;
  final String expected;
  final bool correct;
  final bool skipped;
  final Duration response;

  Map<String, Object?> toJson() => {
    'prompt': prompt,
    'given': given,
    'expected': expected,
    'correct': correct,
    'skipped': skipped,
    'responseUs': response.inMicroseconds,
  };

  factory Attempt.fromJson(Map<String, dynamic> json) => Attempt(
    prompt: json['prompt'] as String,
    given: json['given'] as String,
    expected: json['expected'] as String,
    correct: json['correct'] as bool,
    skipped: json['skipped'] as bool,
    response: Duration(microseconds: (json['responseUs'] as num).toInt()),
  );
}

@immutable
class RoundResult {
  RoundResult({
    required this.type,
    required this.date,
    required this.duration,
    required List<Attempt> attempts,
  }) : attempts = List.unmodifiable(attempts);

  final GameType type;
  final DateTime date;
  final Duration duration;
  final List<Attempt> attempts;

  int get correctCount => attempts.where((attempt) => attempt.correct).length;
  int get skippedCount => attempts.where((attempt) => attempt.skipped).length;
  int get answeredCount => attempts.length - skippedCount;
  double get accuracy => attempts.isEmpty ? 0 : correctCount / attempts.length;
  double get averageResponseSeconds => attempts.isEmpty
      ? 0
      : attempts.fold<int>(
              0,
              (sum, attempt) => sum + attempt.response.inMicroseconds,
            ) /
            attempts.length /
            Duration.microsecondsPerSecond;

  Map<String, Object?> toJson() => {
    'type': type.name,
    'date': date.toIso8601String(),
    'durationUs': duration.inMicroseconds,
    'attempts': attempts.map((attempt) => attempt.toJson()).toList(),
  };

  factory RoundResult.fromJson(Map<String, dynamic> json) => RoundResult(
    type: GameType.values.byName(json['type'] as String),
    date: DateTime.parse(json['date'] as String),
    duration: Duration(microseconds: (json['durationUs'] as num).toInt()),
    attempts: (json['attempts'] as List<dynamic>)
        .map(
          (entry) => Attempt.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList(),
  );
}
