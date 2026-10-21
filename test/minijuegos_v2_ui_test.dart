import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/core/app_theme.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:pg_prep_mobile/features/minijuegos/common/mini_result.dart';
import 'package:pg_prep_mobile/features/minijuegos/hub/mini_results_screen.dart';
import 'package:pg_prep_mobile/features/minijuegos/hub/mini_session_screen.dart';
import 'package:pg_prep_mobile/features/minijuegos/hub/mojarrules_section.dart';
import 'package:pg_prep_mobile/features/minijuegos/memoria_progresiva/chimp_test_screen.dart';

Widget _app(Widget home, {double scale = 1}) => MaterialApp(
  theme: buildAppTheme(),
  locale: const Locale('es', 'MX'),
  supportedLocales: const [Locale('es', 'MX')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

Widget _miniGamesPage() => Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: MojarrulesSection(
        roundDuration: const Duration(minutes: 5),
        difficulty: Difficulty.advanced,
      ),
    ),
  ),
);
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _finish(WidgetTester tester) async {
  await _tap(tester, find.byTooltip('Terminar ronda'));
  await _tap(
    tester,
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Terminar ronda'),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void _phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('FiraSans');
    for (final face in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/FiraSans-$face.otf'));
    }
    await loader.load();
  });
  for (final game in MiniGame.practiceModes) {
    testWidgets(
      'the whole ${game.name} card opens practice and supports compact enlarged text',
      (tester) async {
        _phone(tester, size: const Size(320, 640));
        await tester.pumpWidget(_app(_miniGamesPage(), scale: 1.6));
        await _tap(tester, find.byKey(ValueKey('mini-card-${game.name}')));
        expect(find.byType(MiniSessionScreen), findsOneWidget);
        await _tap(tester, find.text('Entendido, empezar'));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 2500));
        expect(tester.takeException(), isNull);
        await _finish(tester);
        expect(find.byType(MiniResultsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'Chimp ends numeric exposure at 2500 ms and records hidden ascending positions',
    (tester) async {
      _phone(tester);
      final attempts = <Attempt>[];
      final finished = <List<bool>>[];
      await tester.pumpWidget(
        _app(
          ChimpTestScreen(
            totalRounds: 1,
            onAttempt: attempts.add,
            onSessionEnd: finished.add,
          ),
        ),
      );
      final targetKeys = List.generate(
        6,
        (i) => tester
            .widget<GestureDetector>(
              find
                  .ancestor(
                    of: find.byKey(ValueKey('chimp-number-${i + 1}')),
                    matching: find.byType(GestureDetector),
                  )
                  .first,
            )
            .key!,
      );
      final centers = targetKeys
          .map((key) => tester.getCenter(find.byKey(key)))
          .toList();
      await tester.pump(const Duration(milliseconds: 2499));
      expect(find.byKey(const ValueKey('chimp-number-1')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.byKey(const ValueKey('chimp-number-1')), findsNothing);
      final cells = find.byWidgetPredicate(
        (w) =>
            w is GestureDetector &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('chimp-cell-'),
      );
      expect(cells, findsNWidgets(6));
      for (var i = 0; i < targetKeys.length; i++) {
        expect(tester.getCenter(find.byKey(targetKeys[i])), centers[i]);
        await tester.tap(find.byKey(targetKeys[i]));
        await tester.pump();
      }
      expect(attempts.single.correct, isTrue);
      expect(attempts.single.given, '1 → 2 → 3 → 4 → 5 → 6');
      expect(find.text('Ver resultados'), findsOneWidget);
      expect(find.text('Correcta'), findsNothing);
      await _tap(tester, find.text('Ver resultados'));
      expect(finished.single, [true]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('back asks before discarding an unfinished game', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_miniGamesPage()));
    await _tap(tester, find.byKey(const ValueKey('mini-card-progressive')));
    await _tap(tester, find.text('Entendido, empezar'));
    await _tap(tester, find.byTooltip('Salir de la partida'));
    expect(find.text('¿Salir de la partida?'), findsOneWidget);
    await _tap(tester, find.text('Salir sin guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(MiniSessionScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'a deadline closes a confirmation before returning its typed report',
    (tester) async {
      _phone(tester);
      MiniSessionResult? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.push<MiniSessionResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MiniSessionScreen(
                        games: [MiniGame.mixed],
                        roundDuration: Duration(microseconds: 1),
                      ),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await _tap(tester, find.text('Abrir'));
      await tester.ensureVisible(find.text('Entendido, empezar'));
      await tester.tap(find.text('Entendido, empezar'));
      await tester.pump();
      await tester.tap(find.byTooltip('Terminar ronda'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(result?.rounds.length, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(MiniSessionScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
