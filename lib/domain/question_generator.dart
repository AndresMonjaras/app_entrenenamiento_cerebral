import 'dart:math';

import 'models.dart';
import 'stroke_equation.dart';

/// Each digit is a one-based source position for the corresponding output slot.
List<int> applyPermutation(List<int> input, List<int> rule) {
  if (input.length != rule.length ||
      rule.toSet().length != rule.length ||
      rule.any((position) => position < 1 || position > input.length)) {
    throw ArgumentError('La regla debe ser una permutación de las posiciones.');
  }
  return [for (final position in rule) input[position - 1]];
}

List<int> rotateCells(List<int> cells, int size, int quarterTurns) {
  final turns = quarterTurns % 4;
  final result = cells.map((cell) {
    var row = cell ~/ size;
    var column = cell % size;
    for (var turn = 0; turn < turns; turn++) {
      final oldRow = row;
      row = column;
      column = size - 1 - oldRow;
    }
    return row * size + column;
  }).toList()..sort();
  return result;
}

List<int> mirrorCells(List<int> cells, int size, String axis) {
  final result = cells.map((cell) {
    final row = cell ~/ size;
    final column = cell % size;
    return axis == 'vertical'
        ? row * size + size - 1 - column
        : (size - 1 - row) * size + column;
  }).toList()..sort();
  return result;
}

/// Generates independent practice stimuli; no external assessment content is used.
class QuestionGenerator {
  QuestionGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;
  var _gridTrueCount = 0;
  var _gridFalseCount = 0;

  Question generate(
    GameType type,
    Difficulty difficulty, {
    int questionNumber = 1,
  }) => switch (type) {
    GameType.memory => _memory(difficulty, questionNumber),
    GameType.grid => _grid(difficulty, questionNumber),
    GameType.symmetry => _grid(difficulty, questionNumber, symmetryOnly: true),
    GameType.mixed => _grid(
      difficulty,
      questionNumber,
      symmetryOnly: questionNumber.isEven,
    ),
    GameType.switcher => _switch(difficulty),
    GameType.math => _math(),
    GameType.strokes => StrokeEquationGenerator(
      random: _random,
    ).generate(difficulty, questionNumber: questionNumber),
  };

  List<int> _sample(int length, int count) {
    final values = List.generate(length, (index) => index)..shuffle(_random);
    return values.take(count).toList()..sort();
  }

  MemoryQuestion _memory(Difficulty difficulty, int questionNumber) {
    final initial = difficulty == Difficulty.expert ? 3 : 2;
    final count = min(5, initial + max(0, questionNumber - 1) ~/ 4);
    return MemoryQuestion(
      cells: _sample(36, count),
      previewMilliseconds: difficulty == Difficulty.expert ? 2100 : 2600,
    );
  }

  MemorySequenceQuestion generateMemorySequence(
    Difficulty difficulty, {
    int cycleNumber = 1,
  }) {
    final count = min<int>(5, 3 + max<int>(0, cycleNumber - 1));
    final template = _sample(36, 24);
    final positions = <int, Point<double>>{};
    for (final id in template) {
      Point<double>? chosen;
      for (var tries = 0; tries < 1800; tries++) {
        final candidate = Point(
          .06 + _random.nextDouble() * .88,
          .08 + _random.nextDouble() * .84,
        );
        if (positions.values.every((p) => p.distanceTo(candidate) >= .125)) {
          chosen = candidate;
          break;
        }
      }
      // A bounded farthest-position fallback also handles an adversarial RNG.
      if (chosen == null) {
        var bestDistance = -1.0;
        for (var x = 0; x < 18; x++) {
          for (var y = 0; y < 18; y++) {
            final candidate = Point(.06 + x * .88 / 17, .08 + y * .84 / 17);
            final distance = positions.isEmpty
                ? 1.0
                : positions.values
                      .map((p) => p.distanceTo(candidate))
                      .reduce(min);
            if (distance > bestDistance) {
              chosen = candidate;
              bestDistance = distance;
            }
          }
        }
      }
      positions[id] = chosen!;
    }
    final sequence = template.toList()..shuffle(_random);
    return MemorySequenceQuestion(
      templateCells: template,
      sequence: sequence.take(count).toList(),
      positions: positions,
    );
  }

  GridQuestion _grid(
    Difficulty difficulty,
    int questionNumber, {
    bool symmetryOnly = false,
  }) {
    // Balance the two answers without making the sequence predictable.
    final correct = _gridTrueCount == _gridFalseCount
        ? _random.nextBool()
        : _gridTrueCount < _gridFalseCount;
    correct ? _gridTrueCount++ : _gridFalseCount++;
    final tasks = symmetryOnly
        ? const [GridTask.identity, GridTask.symmetry]
        : const [GridTask.rotation, GridTask.combination];
    final task = tasks[max(0, questionNumber - 1) % tasks.length];
    const size = 5;
    final left = _sample(25, 8 + _random.nextInt(9));
    final turns = 1 + _random.nextInt(3);
    final axis = _random.nextBool() ? 'vertical' : 'horizontal';
    if (task == GridTask.combination) {
      final right = _sample(25, 6 + _random.nextInt(7));
      final union = {...left, ...right}.toList()..sort();
      return GridQuestion(
        task: task,
        left: left,
        right: right,
        result: correct ? union : _alter(union, size, difficulty),
        correct: correct,
      );
    }
    final transformed = switch (task) {
      GridTask.rotation => rotateCells(left, size, turns),
      GridTask.symmetry => mirrorCells(left, size, axis),
      GridTask.identity => left,
      GridTask.combination => throw StateError('La unión ya fue generada.'),
    };
    return GridQuestion(
      task: task,
      left: left,
      right: correct ? transformed : _alter(transformed, size, difficulty),
      correct: correct,
      quarterTurns: turns,
      symmetryAxis: axis,
    );
  }

  List<int> _alter(List<int> cells, int size, Difficulty difficulty) {
    final result = cells.toSet();
    // A one-cell discrepancy is intentionally subtle at the expert level.
    final changes = difficulty == Difficulty.expert ? 1 : 2;
    for (final index in _sample(size * size, changes)) {
      result.contains(index) ? result.remove(index) : result.add(index);
    }
    return result.toList()..sort();
  }

  List<int> _permutation() => [1, 2, 3, 4]..shuffle(_random);

  SwitchQuestion _switch(Difficulty difficulty) {
    final input = [0, 1, 2, 3]..shuffle(_random);
    final firstRule = _permutation();
    final optionCount = difficulty == Difficulty.expert ? 4 : 3;
    final options = <List<int>>[];
    while (options.length < optionCount) {
      final option = _permutation();
      if (!options.any((existing) => existing.join() == option.join())) {
        options.add(option);
      }
    }
    final correctIndex = _random.nextInt(options.length);
    final output = applyPermutation(
      applyPermutation(input, firstRule),
      options[correctIndex],
    );
    return SwitchQuestion(
      input: input,
      firstRule: firstRule,
      output: output,
      options: options,
      correctIndex: correctIndex,
    );
  }

  MathQuestion _math() {
    // Pick the number of slots once, independently of difficulty and round order.
    final count = 2 + _random.nextInt(5);
    const symbols = ['+', '−', '×', '÷'];
    for (var attempt = 0; attempt < 500; attempt++) {
      final solution = List.generate(count, (_) => 1 + _random.nextInt(9));
      final operators = List.generate(
        count - 1,
        (_) => symbols[_random.nextInt(symbols.length)],
      );
      final target = evaluateExpression(solution, operators);
      if (target == null ||
          !target.isFinite ||
          target < 1 ||
          target > 999 ||
          (target - target.round()).abs() > 0.0000001) {
        continue;
      }
      final numbers = solution.toList()..shuffle(_random);
      final parts = <String>[solution.first.toString()];
      for (var i = 0; i < operators.length; i++) {
        parts.add(operators[i]);
        parts.add(solution[i + 1].toString());
      }
      return MathQuestion(
        numbers: numbers,
        operators: operators,
        target: target.round(),
        solution: '${parts.join(' ')} = ${target.round()}',
      );
    }
    // Keep the chosen size even if no sampled expression has an integer target.
    final fallback = [
      8,
      2,
      if (count > 2) 3,
      ...List.filled(max(0, count - 3), 1),
    ];
    final operators = [
      '+',
      if (count > 2) '×',
      ...List.filled(max(0, count - 3), '+'),
    ];
    final target = evaluateExpression(fallback, operators)!.toInt();
    final parts = <String>[fallback.first.toString()];
    for (var index = 0; index < operators.length; index++) {
      parts.add(operators[index]);
      parts.add(fallback[index + 1].toString());
    }
    return MathQuestion(
      numbers: fallback.toList()..shuffle(_random),
      operators: operators,
      target: target,
      solution: '${parts.join(' ')} = $target',
    );
  }
}
