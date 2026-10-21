import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/core/app_theme.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:pg_prep_mobile/features/training/training_screen.dart';

Widget _app(Widget home, {double textScale = 1}) => MaterialApp(
  theme: buildAppTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Future<void> _finish(WidgetTester tester) async {
  await _tap(tester, find.widgetWithText(TextButton, 'Terminar ronda'));
  expect(find.text('¿Terminar esta ronda?'), findsOneWidget);
  await _tap(tester, find.widgetWithText(FilledButton, 'Terminar ronda'));
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('FiraSans');
    for (final face in <String>['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/FiraSans-$face.otf'));
    }
    await fonts.load();
  });

  for (final game in GameType.values) {
    for (final textScale in [1.6, 2.0]) {
      testWidgets(
        'instructions and training ${game.name} fit 320px at $textScale text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _app(
              TrainingScreen(games: [game], settings: const TrainingSettings()),
              textScale: textScale,
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Entendido, empezar'), findsOneWidget);
          expect(find.byType(BarraProgresoTiempo), findsNothing);
          expect(tester.takeException(), isNull);

          await _tap(tester, find.text('Entendido, empezar'));
          expect(find.byType(BarraProgresoTiempo), findsOneWidget);
          expect(find.text('ESTÍMULO 01'), findsNothing);
          expect(find.textContaining(RegExp(r'^\d{1,2}:\d{2}$')), findsNothing);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'each round waits for its instructions to be accepted before starting its clock',
    (tester) async {
      List<RoundResult>? results;
      final countdownTimers = <Timer>[];
      await runZoned(
        () async {
          await tester.pumpWidget(
            _app(
              Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    child: const Text('Start'),
                    onPressed: () async {
                      results = await Navigator.of(context)
                          .push<List<RoundResult>>(
                            MaterialPageRoute(
                              builder: (_) => const TrainingScreen(
                                games: [GameType.math, GameType.switcher],
                                settings: TrainingSettings(haptics: false),
                              ),
                            ),
                          );
                    },
                  ),
                ),
              ),
            ),
          );
          await _tap(tester, find.text('Start'));
          expect(find.text('Reto numérico'), findsOneWidget);
          expect(find.text('Entendido, empezar'), findsOneWidget);
          expect(find.byType(BarraProgresoTiempo), findsNothing);
          expect(countdownTimers.where((timer) => timer.isActive), isEmpty);

          await tester.pump(const Duration(minutes: 7));
          expect(find.text('Entendido, empezar'), findsOneWidget);
          expect(find.textContaining('ESTÍMULO'), findsNothing);
          expect(countdownTimers.where((timer) => timer.isActive), isEmpty);
          await _tap(tester, find.text('Entendido, empezar'));
          expect(
            countdownTimers.where((timer) => timer.isActive),
            hasLength(1),
          );
          await _tap(tester, find.text('Omitir'));
          expect(find.byType(MinijuegoCalculo), findsOneWidget);
          expect(find.text('ESTÍMULO 02'), findsNothing);
          expect(find.text('Correcta'), findsNothing);
          expect(find.text('Por mejorar'), findsNothing);
          await _finish(tester);

          expect(find.text('Switch Challenge'), findsOneWidget);
          expect(find.text('Entendido, empezar'), findsOneWidget);
          expect(find.byType(BarraProgresoTiempo), findsNothing);
          expect(find.byType(MinijuegoSwitchChallenge), findsNothing);
          expect(countdownTimers.where((timer) => timer.isActive), isEmpty);
          await tester.pump(const Duration(minutes: 7));
          expect(find.text('Entendido, empezar'), findsOneWidget);
          expect(find.textContaining('ESTÍMULO'), findsNothing);
          expect(countdownTimers.where((timer) => timer.isActive), isEmpty);
          expect(results, isNull);

          await _tap(tester, find.text('Entendido, empezar'));
          expect(
            countdownTimers.where((timer) => timer.isActive),
            hasLength(1),
          );
          expect(find.byType(MinijuegoSwitchChallenge), findsOneWidget);
          expect(find.text('ESTÍMULO 01'), findsNothing);
          expect(find.textContaining(RegExp(r'^\d{1,2}:\d{2}$')), findsNothing);
          await _finish(tester);
          expect(results, hasLength(2));
          expect(results!.first.type, GameType.math);
          expect(results!.first.attempts, hasLength(1));
          expect(results!.first.attempts.single.skipped, isTrue);
          expect(results!.last.type, GameType.switcher);
          expect(results!.last.attempts, isEmpty);
          expect(countdownTimers.where((timer) => timer.isActive), isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
        zoneSpecification: ZoneSpecification(
          createPeriodicTimer: (self, parent, zone, duration, callback) {
            final timer = parent.createPeriodicTimer(zone, duration, callback);
            countdownTimers.add(timer);
            return timer;
          },
        ),
      );
    },
  );
}
