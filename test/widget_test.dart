import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pg_prep_mobile/core/app_theme.dart';
import 'package:pg_prep_mobile/data/progress_repository.dart';
import 'package:pg_prep_mobile/domain/models.dart';
import 'package:pg_prep_mobile/domain/round_controller.dart';
import 'package:pg_prep_mobile/features/home/game_art.dart';
import 'package:pg_prep_mobile/features/home/home_screen.dart';
import 'package:pg_prep_mobile/features/results/results_screen.dart';
import 'package:pg_prep_mobile/features/training/training_screen.dart';

class _MemoryPreferences implements SharedPreferencesAsync {
  final Map<String, Object?> values = {};

  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) async => {
    for (final entry in values.entries)
      if (allowList == null || allowList.contains(entry.key))
        entry.key: entry.value,
  };

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
  theme: buildAppTheme(),
  locale: const Locale('es', 'MX'),
  supportedLocales: const [Locale('es', 'MX')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: true,
    ),
    child: child!,
  ),
  home: child,
);

Future<AppStore> _home(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  _MemoryPreferences? preferences,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final store = AppStore(preferences: preferences ?? _MemoryPreferences());
  await store.initialize();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: store,
      child: _app(const HomeScreen(), textScale: textScale),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Future<void> _startGame(WidgetTester tester, GameType type) async {
  final card = find.ancestor(
    of: find.text(type.title),
    matching: find.byType(SurfacePanel),
  );
  await _tapVisible(
    tester,
    find.descendant(
      of: card,
      matching: find.widgetWithText(TextButton, 'Practicar'),
    ),
  );
  expect(find.byType(TrainingScreen), findsOneWidget);
  expect(find.byType(BarraProgresoTiempo), findsNothing);
  await _tapVisible(tester, find.text('Entendido, empezar'));
  expect(find.byType(BarraProgresoTiempo), findsOneWidget);
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('FiraSans');
    for (final face in <String>['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/FiraSans-$face.otf'));
    }
    await loader.load();
  });

  for (final viewport in <(String, Size, double)>[
    ('phone', const Size(390, 844), 1),
    ('desktop', const Size(1440, 1000), 1),
    ('compact phone', const Size(320, 844), 1),
    ('compact phone with large text', const Size(320, 844), 2),
  ]) {
    testWidgets('home, empty progress and guide fit ${viewport.$1}', (
      tester,
    ) async {
      await _home(tester, size: viewport.$2, textScale: viewport.$3);
      expect(find.text('Pequeñas sesiones. Grandes avances.'), findsOneWidget);
      for (final type in GameType.practiceModes) {
        expect(find.text(type.title), findsOneWidget);
      }
      expect(tester.takeException(), isNull);

      await _tapVisible(tester, find.text('Tu progreso'));
      expect(find.text('Tu historia empieza con un reto'), findsOneWidget);
      expect(find.text('Elegir un reto'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tapVisible(
        tester,
        find.text(viewport.$2.width >= 960 ? 'Cómo funciona' : 'Guía'),
      );
      expect(
        find.text('Conoce el reto.\nEncuentra tu estrategia.'),
        findsOneWidget,
      );
      for (final type in GameType.practiceModes) {
        expect(find.text(type.instructions), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final type in GameType.practiceModes) {
    testWidgets(
      'tapping ${type.name} artwork opens its practice instructions',
      (tester) async {
        final store = await _home(tester);
        await _tapVisible(
          tester,
          find.byWidgetPredicate(
            (widget) => widget is GameArt && widget.type == type,
          ),
        );
        expect(find.byType(TrainingScreen), findsOneWidget);
        expect(
          tester.widget<TrainingScreen>(find.byType(TrainingScreen)).games,
          [type],
        );
        expect(find.text('Entendido, empezar'), findsOneWidget);
        expect(find.byType(BarraProgresoTiempo), findsNothing);
        expect(store.history, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the complete test includes every practical game', (
    tester,
  ) async {
    await _home(tester);
    await _tapVisible(tester, find.text('Iniciar test completo'));
    final training = tester.widget<TrainingScreen>(find.byType(TrainingScreen));
    expect(training.games, orderedEquals(GameType.practiceModes));
    expect(training.games, hasLength(5));
    expect(find.text('Entendido, empezar'), findsOneWidget);
    expect(find.byType(BarraProgresoTiempo), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the main illustration also opens the complete test instructions',
    (tester) async {
      await _home(tester, size: const Size(1440, 1000));
      await _tapVisible(tester, find.byType(HeroArtwork));
      final training = tester.widget<TrainingScreen>(
        find.byType(TrainingScreen),
      );
      expect(training.games, orderedEquals(GameType.practiceModes));
      expect(find.text('Entendido, empezar'), findsOneWidget);
      expect(find.byType(BarraProgresoTiempo), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings save duration and difficulty and restore the selection',
    (tester) async {
      final preferences = _MemoryPreferences();
      final store = await _home(tester, preferences: preferences);
      await _tapVisible(tester, find.byTooltip('Ajustes de entrenamiento'));
      await _tapVisible(tester, find.text('6 minutos'));
      await _tapVisible(tester, find.text('Experto'));
      await _tapVisible(tester, find.text('Guardar ajustes'));

      expect(store.settings.roundMinutes, 6);
      expect(store.settings.difficulty, Difficulty.expert);
      final saved = jsonDecode(
        preferences.values['pg_prep.settings.v1']! as String,
      ) as Map<String, dynamic>;
      expect(saved['roundMinutes'], 6);
      expect(saved['difficulty'], 'expert');

      await _tapVisible(tester, find.byTooltip('Ajustes de entrenamiento'));
      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        {6},
      );
      expect(
        tester
            .widget<SegmentedButton<Difficulty>>(
              find.byType(SegmentedButton<Difficulty>),
            )
            .selected,
        {Difficulty.expert},
      );
      await _tapVisible(tester, find.text('5 minutos'));
      await _tapVisible(
        tester,
        find.descendant(
          of: find.byType(SegmentedButton<Difficulty>),
          matching: find.text('Avanzado'),
        ),
      );
      await _tapVisible(tester, find.text('Guardar ajustes'));
      expect(store.settings.roundMinutes, 5);
      expect(store.settings.difficulty, Difficulty.advanced);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switch advances silently and saves a reviewable report in history',
    (tester) async {
      final preferences = _MemoryPreferences();
      final store = await _home(tester, preferences: preferences);
      await _startGame(tester, GameType.switcher);
      expect(find.text('ESTÍMULO 01'), findsNothing);
      final question = tester
          .widget<MinijuegoSwitchChallenge>(
            find.byType(MinijuegoSwitchChallenge),
          )
          .question;
      await _tapVisible(tester, find.byKey(const ValueKey('switch-option-0')));
      expect(
        tester
            .widget<MinijuegoSwitchChallenge>(
              find.byType(MinijuegoSwitchChallenge),
            )
            .question,
        isNot(same(question)),
      );
      expect(find.text('ESTÍMULO 02'), findsNothing);
      expect(find.text('Correcta'), findsNothing);
      expect(find.text('Por mejorar'), findsNothing);
      expect(find.textContaining('Respuesta esperada:'), findsNothing);
      expect(store.history, isEmpty);

      await _tapVisible(
        tester,
        find.widgetWithText(TextButton, 'Terminar ronda'),
      );
      expect(find.text('¿Terminar esta ronda?'), findsOneWidget);
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Terminar ronda'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(find.text('Así fue tu entrenamiento.'), findsOneWidget);
      expect(store.history.length, 1);
      expect(store.history.single.type, GameType.switcher);
      expect(store.history.single.attempts.length, 1);

      await _tapVisible(tester, find.byType(ExpansionTile).first);
      expect(
        find.text('Tu respuesta: ${question.options.first.join()}'),
        findsOneWidget,
      );
      expect(find.textContaining('Respuesta esperada:'), findsOneWidget);
      await _tapVisible(tester, find.text('Volver a mi espacio'));
      await _tapVisible(tester, find.text('Tu progreso'));
      expect(find.text('Tus últimas rondas'), findsOneWidget);
      expect(find.textContaining('1 respuestas'), findsOneWidget);
      expect(
        jsonDecode(preferences.values['pg_prep.history.v1']! as String),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'memory blocks touches during exposure and accepts exact positions afterward',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      var elapsed = Duration.zero;
      final controller = RoundController(
        GameType.memory,
        const TrainingSettings(haptics: false),
        random: Random(7),
        elapsedNow: () => elapsed,
        mixedSequences: false,
      );
      final question = controller.currentQuestion as MemoryQuestion;
      Object? submitted;
      var disposed = false;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        if (!disposed) {
          disposed = true;
          controller.dispose();
        }
      });
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => MinijuegoMemoriaPuntos(
                  question: question,
                  controller: controller,
                  onSubmit: (answer) => submitted = answer,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('01  OBSERVA'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      final firstCell = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Fila 1, columna 1',
      );
      final firstTouch = find.descendant(
        of: firstCell,
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(firstTouch).onTap, isNull);
      expect(submitted, isNull);

      elapsed = Duration(milliseconds: question.previewMilliseconds);
      controller.refresh();
      await tester.pumpAndSettle();
      expect(find.text('02  RECUERDA'), findsNothing);
      for (final cell in question.cells) {
        final target = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Fila ${cell ~/ question.gridSize + 1}, columna ${cell % question.gridSize + 1}',
        );
        await _tapVisible(
          tester,
          find.descendant(of: target, matching: find.byType(InkWell)),
        );
      }
      await _tapVisible(tester, find.text('Confirmar posiciones'));
      expect(submitted, unorderedEquals(question.cells));
      disposed = true;
      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
