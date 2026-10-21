import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';

/// Integer coordinates prevent a tolerance from accepting tiny deformations.
typedef TracePoint = ({int x, int y});

@immutable
class LineStroke {
  factory LineStroke(TracePoint a, TracePoint b) {
    if (a == b ||
        [a, b].any((p) => p.x < 0 || p.y < 0 || p.x > extent || p.y > extent)) {
      throw ArgumentError(
        'El trazo requiere dos puntos distintos dentro del plano.',
      );
    }
    final ordered = a.x < b.x || (a.x == b.x && a.y < b.y);
    return LineStroke._(ordered ? a : b, ordered ? b : a);
  }
  const LineStroke._(this.start, this.end);
  static const extent = 72;
  final TracePoint start;
  final TracePoint end;
  @override
  bool operator ==(Object other) =>
      other is LineStroke && start == other.start && end == other.end;
  @override
  int get hashCode => Object.hash(start, end);
}

/// Compare geometric coverage, independent of direction, duplicates or whether
/// one continuous line was supplied as several collinear fragments.
bool sameStrokeGeometry(Iterable<LineStroke> a, Iterable<LineStroke> b) {
  Map<(int, int, int), List<(int, int)>> coverage(
    Iterable<LineStroke> strokes,
  ) {
    final grouped = <(int, int, int), List<(int, int)>>{};
    for (final line in strokes) {
      final dx = line.end.x - line.start.x;
      final dy = line.end.y - line.start.y;
      final divisor = dx.abs().gcd(dy.abs());
      final vx = dx ~/ divisor;
      final vy = dy ~/ divisor;
      final key = (vx, vy, vx * line.start.y - vy * line.start.x);
      final t0 = vx * line.start.x + vy * line.start.y;
      final t1 = vx * line.end.x + vy * line.end.y;
      (grouped[key] ??= []).add((min(t0, t1), max(t0, t1)));
    }
    return grouped.map((key, intervals) {
      intervals.sort((a, b) => a.$1.compareTo(b.$1));
      final merged = <(int, int)>[];
      for (final interval in intervals) {
        if (merged.isNotEmpty && interval.$1 <= merged.last.$2) {
          merged[merged.length - 1] = (
            merged.last.$1,
            max(merged.last.$2, interval.$2),
          );
        } else {
          merged.add(interval);
        }
      }
      return MapEntry(key, merged);
    });
  }

  final left = coverage(a);
  final right = coverage(b);
  return left.length == right.length &&
      left.entries.every((entry) => listEquals(entry.value, right[entry.key]));
}

@immutable
class StrokeEquationQuestion extends Question {
  StrokeEquationQuestion({
    required Iterable<LineStroke> left,
    required Iterable<LineStroke> right,
    required Iterable<LineStroke> result,
  }) : left = List.unmodifiable(left),
       right = List.unmodifiable(right),
       result = List.unmodifiable(result) {
    if (this.left.isEmpty || this.right.isEmpty || this.result.isEmpty) {
      throw ArgumentError('La ecuación necesita tres figuras.');
    }
    correct = sameStrokeGeometry([...this.left, ...this.right], this.result);
  }
  final List<LineStroke> left;
  final List<LineStroke> right;
  final List<LineStroke> result;
  late final bool correct;
  @override
  String get prompt => '¿La superposición de todos los trazos es exacta?';
  @override
  String get correctAnswerLabel => correct ? 'Sí' : 'No';
  @override
  bool check(Object? answer) => answer is bool && answer == correct;
  @override
  String answerLabel(Object? answer) =>
      answer is bool ? (answer ? 'Sí' : 'No') : super.answerLabel(answer);
}

enum StrokeAlteration { none, missing, extra, displaced, deformed }

class StrokeEquationGenerator {
  StrokeEquationGenerator({Random? random}) : _random = random ?? Random();
  final Random _random;
  static List<LineStroke> _pool() => [
    for (var y = 0; y <= 6; y++)
      for (var x = 0; x <= 6; x++)
        for (final (dx, dy) in [(1, 0), (0, 1), (1, 1), (-1, 1)])
          if (x + dx >= 0 && x + dx <= 6 && y + dy <= 6)
            LineStroke(
              (x: x * 12, y: y * 12),
              (x: (x + dx) * 12, y: (y + dy) * 12),
            ),
  ];
  StrokeEquationQuestion generate(
    Difficulty difficulty, {
    int questionNumber = 1,
    StrokeAlteration? alteration,
  }) {
    final pool = _pool()..shuffle(_random);
    final count =
        (difficulty == Difficulty.expert ? 21 : 14) +
        min(5, questionNumber ~/ 4).toInt();
    final shared = pool.take(4).toList();
    final left = [...shared, ...pool.skip(4).take(count)];
    final right = [...shared, ...pool.skip(4 + count).take(count)];
    final result = {...left, ...right}.toList()..shuffle(_random);
    final change =
        alteration ??
        (_random.nextBool()
            ? StrokeAlteration.none
            : StrokeAlteration.values[1 + _random.nextInt(4)]);
    switch (change) {
      case StrokeAlteration.none:
        break;
      case StrokeAlteration.missing:
        result.removeLast();
      case StrokeAlteration.extra:
        result.add(pool.firstWhere((line) => !result.contains(line)));
      case StrokeAlteration.displaced:
      case StrokeAlteration.deformed:
        final original = result.removeLast();
        final vertical = original.start.x == original.end.x;
        final delta =
            (vertical
                    ? max(original.start.x, original.end.x)
                    : max(original.start.y, original.end.y)) <
                LineStroke.extent
            ? 1
            : -1;
        TracePoint shift(TracePoint p) =>
            (x: p.x + (vertical ? delta : 0), y: p.y + (vertical ? 0 : delta));
        result.add(
          LineStroke(
            change == StrokeAlteration.deformed
                ? original.start
                : shift(original.start),
            shift(original.end),
          ),
        );
    }
    return StrokeEquationQuestion(left: left, right: right, result: result);
  }

  static StrokeEquationQuestion example({bool correct = true}) {
    LineStroke line(int x, int y, int a, int b) =>
        LineStroke((x: x, y: y), (x: a, y: b));
    final left = [line(0, 0, 0, 72), line(0, 36, 36, 36)];
    final right = [line(72, 0, 72, 72), line(36, 36, 72, 36)];
    return StrokeEquationQuestion(
      left: left,
      right: right,
      result: [...left, ...right, if (!correct) line(36, 0, 36, 36)],
    );
  }
}
