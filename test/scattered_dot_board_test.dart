import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/core/app_theme.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:pg_prep_mobile/features/training/mixed_sequence.dart';
import 'package:pg_prep_mobile/features/training/mixed_walkthrough.dart';
import 'package:pg_prep_mobile/features/training/scattered_dot_board.dart';

MemorySequenceQuestion _question() => MemorySequenceQuestion(
  templateCells: [0, 1, 2, 3, 4, 5],
  sequence: [4, 1, 5],
  positions: const {
    0: Point(.15, .15),
    1: Point(.19, .15),
    2: Point(.75, .20),
    3: Point(.30, .65),
    4: Point(.60, .55),
    5: Point(.90, .85),
  },
);

Widget _app(Widget child, {bool reducedMotion = true}) => MaterialApp(
  theme: buildAppTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reducedMotion,
      textScaler: const TextScaler.linear(2),
    ),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: child,
    ),
  ),
);

void _expectFlashAlpha(WidgetTester tester, double alpha) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(ScatteredDotBoard),
      matching: find.byType(CustomPaint),
    ),
  );
  expect(
    (Canvas canvas) => paint.painter!.paint(canvas, const Size(280, 170)),
    paints..something((method, arguments) {
      if (method != #drawCircle) return false;
      final circlePaint = arguments[2] as Paint;
      return circlePaint.style == PaintingStyle.fill &&
          (circlePaint.color.r - ScatteredDotBoard.red.r).abs() < .01 &&
          (circlePaint.color.g - ScatteredDotBoard.red.g).abs() < .01 &&
          (circlePaint.color.a - alpha).abs() < .01;
    }),
  );
}

void main() {
  testWidgets('numbered flash fades out and back in over 500ms halves', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        PointFlashView(
          question: PointFlashQuestion(
            memory: _question(),
            index: 0,
            durationMilliseconds: 3500,
          ),
        ),
        reducedMotion: false,
      ),
    );
    await tester.pump();
    _expectFlashAlpha(tester, 1);
    for (final alpha in [.5, 0.0, .5, 1.0]) {
      await tester.pump(const Duration(milliseconds: 250));
      _expectFlashAlpha(tester, alpha);
    }
    expect(find.byKey(const ValueKey('flash-target-4')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scattered recall keeps distractors, order and all selection edits',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.reset);
      final changes = <List<int>>[];
      Object? submitted;
      await tester.pumpWidget(
        _app(
          MemorySequenceRecall(
            question: _question(),
            onSubmit: (value) => submitted = value,
            onSelectionChanged: changes.add,
          ),
        ),
      );
      expect(find.byType(ScatteredDotBoard), findsOneWidget);
      for (var id = 0; id < 6; id++) {
        expect(find.byKey(ValueKey('recall-cell-$id')), findsOneWidget);
      }

      // The neighboring 48px hit regions overlap. Selecting a center must still
      // choose that point rather than whichever Stack child happens to be last.
      await tester.tapAt(
        tester.getRect(find.byKey(const ValueKey('recall-cell-0'))).center,
      );
      await tester.pump();
      expect(changes.last, [0]);
      expect(find.byKey(const ValueKey('recall-order-0')), findsOneWidget);
      await tester.tapAt(
        tester.getRect(find.byKey(const ValueKey('recall-cell-1'))).center,
      );
      await tester.pump();
      expect(changes.last, [0, 1]);
      await tester.tapAt(
        tester.getRect(find.byKey(const ValueKey('recall-cell-0'))).center,
      );
      await tester.pump();
      expect(changes.last, isEmpty);
      expect(changes.first, [0]);

      for (final id in [4, 1, 5]) {
        await tester.tapAt(
          tester.getRect(find.byKey(ValueKey('recall-cell-$id'))).center,
        );
        await tester.pump();
      }
      expect(changes.last, [4, 1, 5]);
      expect(find.text('3 de 3 elegidos'), findsNothing);
      final marker = tester.widget<Text>(
        find.byKey(const ValueKey('recall-order-5')),
      );
      expect(marker.data, '3');
      expect(marker.style!.color, Colors.white);
      await tester.ensureVisible(find.text('Deshacer'));
      await tester.tap(find.text('Deshacer'));
      await tester.pump();
      expect(changes.last, [4, 1]);
      await tester.tap(find.text('Limpiar'));
      await tester.pump();
      expect(changes.last, isEmpty);

      for (final id in [4, 1, 5]) {
        final target = find.byKey(ValueKey('recall-cell-$id'));
        await tester.ensureVisible(target);
        await tester.tapAt(tester.getRect(target).center);
        await tester.pump();
      }
      await tester.ensureVisible(find.text('Confirmar secuencia'));
      await tester.tap(find.text('Confirmar secuencia'));
      await tester.pump();
      expect(submitted, [4, 1, 5]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('scattered points retain accessible selection after resizing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final question = _question();
    final changes = <List<int>>[];
    await tester.pumpWidget(
      _app(
        MemorySequenceRecall(
          question: question,
          onSubmit: (_) {},
          onSelectionChanged: changes.add,
        ),
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('Punto 5'));
    await tester.pump();
    tester.view.physicalSize = const Size(600, 740);
    await tester.pump();
    tester.semantics.tap(find.semantics.byLabel('Punto 2'));
    await tester.pump();
    expect(changes.last, [4, 1]);
    expect(
      tester.widget<ScatteredDotBoard>(find.byType(ScatteredDotBoard)).question,
      same(question),
    );
    expect(find.byKey(const ValueKey('recall-order-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('recall-order-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview teaches point then figure for all three pairs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const MixedSequenceWalkthrough(type: GameType.mixed),
        reducedMotion: false,
      ),
    );
    await tester.pump();
    for (var number = 1; number <= 3; number++) {
      expect(find.text('Recuerda el punto $number'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3500));
      expect(
        find.text(
          number == 2
              ? 'Resuelve Simetría e identidad'
              : 'Resuelve Grid Challenge',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
    }
    expect(
      find.text('Marca 1 → 2 → 3 en las posiciones que recuerdas'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
