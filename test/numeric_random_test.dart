import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:pg_prep_mobile/domain/question_generator.dart';

void main() {
  group('Random numeric exercises', () {
    for (final difficulty in Difficulty.values) {
      test(
        '${difficulty.name} varies from two to six slots at the same index',
        () {
          final generator = QuestionGenerator(random: Random(612));
          final sizes = <int>{};
          final symbols = <String>{};
          for (var sample = 0; sample < 200; sample++) {
            final question = generator.generate(
              GameType.math,
              difficulty,
              questionNumber: 1,
            ) as MathQuestion;
            sizes.add(question.numbers.length);
            symbols.addAll(question.operators);
            expect(question.numbers.length, inInclusiveRange(2, 6));
            expect(question.operators.length, question.numbers.length - 1);
            expect(question.numbers, everyElement(inInclusiveRange(1, 9)));
            expect(question.target, inInclusiveRange(1, 999));
            expect(question.check(_solutionNumbers(question)), isTrue);
          }
          expect(sizes, {2, 3, 4, 5, 6});
          expect(symbols, {'+', '−', '×', '÷'});
        },
      );
    }

    test('a seed reproduces samples regardless of index or difficulty', () {
      final first = QuestionGenerator(random: Random(879));
      final second = QuestionGenerator(random: Random(879));
      for (var index = 0; index < 100; index++) {
        final left = first.generate(
          GameType.math,
          Difficulty.advanced,
          questionNumber: index + 1,
        ) as MathQuestion;
        final right = second.generate(
          GameType.math,
          Difficulty.expert,
          questionNumber: 99 - index,
        ) as MathQuestion;
        expect(left.numbers, right.numbers);
        expect(left.operators, right.operators);
        expect(left.target, right.target);
        expect(left.solution, right.solution);
      }
    });

    test('every generated exercise has a complete valid permutation', () {
      final generator = QuestionGenerator(random: Random(374));
      final sizes = <int>{};
      var alternativeFound = false;
      for (var index = 0; index < 80; index++) {
        final question = generator.generate(
          GameType.math,
          Difficulty.expert,
        ) as MathQuestion;
        sizes.add(question.numbers.length);
        final solution = _solutionNumbers(question);
        var solutions = 0;
        for (final permutation in _permutations(question.numbers)) {
          final value = evaluateExpression(permutation, question.operators);
          final reachesTarget =
              value != null && (value - question.target).abs() < 0.0000001;
          expect(question.check(permutation), reachesTarget);
          if (reachesTarget) {
            solutions++;
            if (permutation.join(',') != solution.join(',')) {
              alternativeFound = true;
            }
          }
        }
        expect(solutions, greaterThan(0));
        expect(
          question.check(solution.take(solution.length - 1).toList()),
          isFalse,
        );
      }
      expect(sizes, {2, 3, 4, 5, 6});
      expect(alternativeFound, isTrue);
    });

    test('alternative arrangements honor precedence and repeated numbers', () {
      final question = MathQuestion(
        numbers: [2, 2, 4, 1, 1, 1],
        operators: ['+', '×', '−', '+', '÷'],
        target: 10,
        solution: '2 + 2 × 4 − 1 + 1 ÷ 1 = 10',
      );
      expect(question.check([2, 2, 4, 1, 1, 1]), isTrue);
      expect(question.check([2, 4, 2, 1, 1, 1]), isTrue);
      // It reaches 10 but replaces an available 1 with an extra 4.
      expect(evaluateExpression([1, 2, 4, 1, 4, 2], question.operators), 10);
      expect(question.check([1, 2, 4, 1, 4, 2]), isFalse);
      expect(question.check([2, 2, 4, 1, 1, 2]), isFalse);
      expect(question.check([2, 4, 2, 1, 1]), isFalse);
    });

    for (var count = 2; count <= 6; count++) {
      test('bounded fallback keeps all $count randomly chosen slots', () {
        final random = _InvalidDivisionRandom(count);
        final question = QuestionGenerator(
          random: random,
        ).generate(GameType.math, Difficulty.advanced) as MathQuestion;
        expect(random.sampledNumbers, 500 * count);
        expect(question.numbers.length, count);
        expect(question.operators.length, count - 1);
        expect(question.check(_solutionNumbers(question)), isTrue);
        expect(question.target, inInclusiveRange(1, 999));
      });
    }
  });
}

List<int> _solutionNumbers(MathQuestion question) => question.solution
    .split('=')
    .first
    .trim()
    .split(RegExp(r'\s+'))
    .indexed
    .where((part) => part.$1.isEven)
    .map((part) => int.parse(part.$2))
    .toList();

Iterable<List<int>> _permutations(List<int> input) sync* {
  if (input.isEmpty) {
    yield <int>[];
    return;
  }
  final used = <int>{};
  for (var index = 0; index < input.length; index++) {
    if (!used.add(input[index])) continue;
    final remaining = input.toList()..removeAt(index);
    for (final suffix in _permutations(remaining)) {
      yield [input[index], ...suffix];
    }
  }
}

/// Every trial becomes 1 ÷ 9 [÷ 9 ...], which is never an integer target.
class _InvalidDivisionRandom implements Random {
  _InvalidDivisionRandom(this.count);

  final int count;
  var sampledNumbers = 0;

  @override
  int nextInt(int max) {
    if (max == 5) return count - 2;
    if (max == 9) return sampledNumbers++ % count == 0 ? 0 : 8;
    if (max == 4) return 3;
    return 0;
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}
