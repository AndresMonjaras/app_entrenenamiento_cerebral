import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/core/app_theme.dart';
import 'package:pg_prep_mobile/domain/stroke_equation.dart';
import 'package:pg_prep_mobile/features/training/stroke_equation.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'stroke equation at $width shows only the equation and answer controls',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.reset);
        Object? submitted;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: StrokeEquationGame(
                  question: StrokeEquationGenerator.example(correct: false),
                  onSubmit: (value) => submitted = value,
                ),
              ),
            ),
          ),
        );
        final labels = tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .toList();
        expect(labels, containsAll(['+', '=', 'Sí', 'No']));
        expect(
          labels.where((text) => !['+', '=', 'Sí', 'No'].contains(text)),
          isEmpty,
        );
        expect(find.byType(CustomPaint), findsWidgets);
        await tester.tap(find.text('No'));
        await tester.pump();
        expect(submitted, false);
        expect(find.text('Correcta'), findsNothing);
        expect(find.text('Incorrecta'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
