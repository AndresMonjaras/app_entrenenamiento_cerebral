import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../data/progress_repository.dart';
import '../../domain/models.dart';
import '../results/results_screen.dart';
import '../minijuegos/hub/mojarrules_section.dart';
import '../training/training_screen.dart';
import 'game_art.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _section = 0;

  Future<void> _start(List<GameType> games) async {
    final store = context.read<AppStore>();
    final settings = store.settings;
    final results = await Navigator.of(context).push<List<RoundResult>>(
      appRoute(TrainingScreen(games: games, settings: settings)),
    );
    if (results == null || results.isEmpty || !mounted) return;
    await store.addResults(results);
    if (!mounted) return;
    await Navigator.of(context).push(appRoute(ResultsScreen(results: results)));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              _Sidebar(
                selected: _section,
                onSelect: (value) => setState(() => _section = value),
                onSettings: () => _settings(context),
              ),
            Expanded(
              child: Column(
                children: [
                  _topBar(wide),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: reduceMotion(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      child: SingleChildScrollView(
                        key: ValueKey(_section),
                        padding: EdgeInsets.fromLTRB(
                          wide ? 40 : 20,
                          wide ? 30 : 18,
                          wide ? 40 : 20,
                          30,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1120),
                            child: switch (_section) {
                              0 => _training(),
                              1 => _ProgressView(
                                onStart: () => setState(() => _section = 0),
                              ),
                              _ => _GuideView(onStart: _start),
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _section,
              onDestinationSelected: (value) =>
                  setState(() => _section = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Juegos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  label: 'Tu progreso',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  label: 'Guía',
                ),
              ],
            ),
    );
  }

  Widget _topBar(bool wide) => Container(
    padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20, vertical: 12),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        if (!wide) ...[const _BrandMark(size: 30), const SizedBox(width: 10)],
        Expanded(
          child: Text(
            wide
                ? [
                    'Menú principal',
                    'Tu progreso, paso a paso',
                    'Conoce cada desafío',
                  ][_section]
                : 'P&G Prep',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        if (wide) ...[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'A tu ritmo. Cada día.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(width: 24),
        ],
        IconButton(
          tooltip: 'Ajustes de entrenamiento',
          onPressed: () => _settings(context),
          icon: const Icon(Icons.tune_rounded, size: 21),
        ),
        const SizedBox(width: 6),
        const CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.mint,
          child: Text(
            'Tú',
            style: TextStyle(
              color: AppColors.green,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _training() {
    final settings = context.watch<AppStore>().settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PRACTICA CON INTENCIÓN',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Pequeñas sesiones. Grandes avances.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Pon a prueba tu concentración, encuentra tu ritmo y supera tu última marca.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 26),
        _SimulationHero(
          minutes: settings.roundMinutes,
          onStart: () => _start(GameType.practiceModes),
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Un reto para cada habilidad',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Elige en qué quieres enfocarte hoy.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _settings(context),
              icon: const Icon(Icons.tune_rounded, size: 15),
              label: Text(
                settings.difficulty == Difficulty.expert
                    ? 'Experto'
                    : 'Avanzado',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 620 ? 2 : 1;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                for (final type in GameType.practiceModes)
                  SizedBox(
                    width:
                        (constraints.maxWidth - (columns - 1) * 18) / columns,
                    child: _GameCard(
                      type: type,
                      minutes: settings.durationFor(type).inMinutes,
                      onStart: () => _start([type]),
                      onInfo: () =>
                          _gameInfo(context, type, () => _start([type])),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        MojarrulesSection(
          roundDuration: Duration(minutes: settings.roundMinutes),
          difficulty: settings.difficulty,
        ),
        const SizedBox(height: 24),
        SurfacePanel(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFFAD9254),
                  size: 19,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'La constancia hace la diferencia. Una sesión al día es un buen comienzo.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const _Footer(),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.onSettings,
  });
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Container(
    width: 230,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: AppColors.line)),
    ),
    padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            _BrandMark(size: 39),
            SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'P&G Prep',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 23,
                    letterSpacing: -.7,
                  ),
                ),
                Text(
                  'M O B I L E',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 55),
        const Padding(
          padding: EdgeInsets.only(left: 14),
          child: Text(
            'TU ESPACIO',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.9,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Material(
              color: selected == i ? AppColors.mint : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        [
                          Icons.grid_view_rounded,
                          Icons.insights_rounded,
                          Icons.auto_stories_outlined,
                        ][i],
                        size: 19,
                        color: selected == i
                            ? AppColors.green
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        ['Menú principal', 'Tu progreso', 'Cómo funciona'][i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected == i
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected == i
                              ? AppColors.green
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.spa_outlined, size: 24, color: AppColors.green),
              SizedBox(height: 13),
              Text(
                'Prepárate a tu manera.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 7),
              Text(
                'Cada intento te acerca a tu mejor versión.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: onSettings,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Ajustes', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text(
            'P&G PREP MOBILE  /  1.0',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.1,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.green,
      borderRadius: BorderRadius.circular(size * .29),
    ),
    child: Icon(
      Icons.all_inclusive_rounded,
      color: const Color(0xFFE4F4D9),
      size: size * .68,
    ),
  );
}

class _SimulationHero extends StatelessWidget {
  const _SimulationHero({required this.minutes, required this.onStart});
  final int minutes;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 670;
      return GestureDetector(
        key: const ValueKey('full-test-card'),
        onTap: onStart,
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              if (wide)
                const Positioned(
                  right: 25,
                  top: 8,
                  bottom: 8,
                  width: 310,
                  child: HeroArtwork(),
                ),
              Padding(
                padding: EdgeInsets.all(wide ? 32 : 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wide
                        ? constraints.maxWidth - 320
                        : constraints.maxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SmallTag(
                        'TEST COMPLETO',
                        background: Color(0xFFC7E9D8),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Tu mejor versión\nse entrena.',
                        style: TextStyle(
                          fontSize: wide ? 40 : 34,
                          height: 1.1,
                          letterSpacing: -1.5,
                          color: const Color(0xFF1D5946),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Todos los juegos prácticos, en una sesión.\nCon una guía visual antes de cada reto.',
                        style: TextStyle(
                          color: Color(0xFF507969),
                          fontSize: 13,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 23),
                      Wrap(
                        spacing: 18,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: onStart,
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            label: const Text('Iniciar test completo'),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 15,
                                color: Color(0xFF507969),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${TrainingSettings(roundMinutes: minutes).simulationDuration.inMinutes} min · ${GameType.practiceModes.length} retos',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF507969),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.type,
    required this.minutes,
    required this.onStart,
    required this.onInfo,
  });
  final GameType type;
  final int minutes;
  final VoidCallback onStart;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) => SurfacePanel(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('game-card-${type.name}'),
        onTap: onStart,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 117,
              child: Ink(
                decoration: BoxDecoration(
                  color: gameBackground(type),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(19),
                  ),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '0${type.index + 1}',
                            style: TextStyle(
                              color: gameColor(type).withValues(alpha: .5),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 11),
                          Icon(
                            gameIcon(type),
                            color: gameColor(type),
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: GameArt(
                          key: ValueKey('game-art-${type.name}'),
                          type: type,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameSkill(type),
                    style: TextStyle(
                      color: gameColor(type),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          type.title,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -.5,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onInfo,
                        tooltip: 'Cómo jugar ${type.title}',
                        icon: const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.muted,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    switch (type) {
                      GameType.memory =>
                        'Observa, retén y reconstruye cada posición.',
                      GameType.grid => 'Memoriza un punto y resuelve cuadrículas en cada ciclo.',
                      GameType.symmetry =>
                        'Memoriza un punto y compara figuras simétricas.',
                      GameType.switcher =>
                        'Descifra las reglas. Transforma la secuencia.',
                      GameType.mixed =>
                        'Punto → Grid o Simetría → recuperación en orden.',
                      GameType.strokes =>
                        'Superpón cada trazo. Detecta la mínima diferencia.',
                      GameType.math =>
                        'Conecta números y alcanza el resultado.',
                    },
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 21),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: AppColors.muted,
                              ),
                            ),
                            TextSpan(text: '  $minutes min'),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      const Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                Icons.bar_chart_rounded,
                                size: 15,
                                color: AppColors.muted,
                              ),
                            ),
                            TextSpan(text: '  Alta exigencia'),
                          ],
                        ),
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      TextButton.icon(
                        onPressed: onStart,
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        style: TextButton.styleFrom(
                          foregroundColor: gameColor(type),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        label: const Text(
                          'Practicar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final history = store.history;
    final answered = history.fold<int>(0, (sum, r) => sum + r.attempts.length);
    final correct = history.fold<int>(0, (sum, r) => sum + r.correctCount);
    final seconds = history.fold<int>(
      0,
      (sum, r) => sum + r.duration.inSeconds,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cada intento cuenta.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Mira lo que has conseguido y descubre dónde puedes crecer.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 28),
        if (store.storageError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              store.storageError!,
              style: const TextStyle(color: AppColors.coral),
            ),
          ),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            StatTile(
              value: '${history.length}',
              label: 'Rondas completadas',
              icon: Icons.flag_outlined,
            ),
            StatTile(
              value: answered == 0
                  ? '—'
                  : '${(correct / answered * 100).round()}%',
              label: 'Precisión global',
              icon: Icons.track_changes_rounded,
            ),
            StatTile(
              value: '${seconds ~/ 60} min',
              label: 'Tiempo entrenado',
              icon: Icons.timelapse_rounded,
            ),
          ],
        ),
        const SizedBox(height: 28),
        if (history.isEmpty)
          SurfacePanel(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    const Icon(
                      Icons.insights_rounded,
                      size: 54,
                      color: AppColors.green,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Tu historia empieza con un reto',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Al finalizar tu primera ronda, aquí verás tus resultados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 25),
                    FilledButton(
                      onPressed: onStart,
                      child: const Text('Elegir un reto'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tus últimas rondas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => _clearHistory(context),
                child: const Text('Borrar historial'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final result in history)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: gameBackground(result.type),
                    child: Icon(
                      gameIcon(result.type),
                      color: gameColor(result.type),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    result.type.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    '${formatDate(result.date)} · ${result.attempts.length} respuestas',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(result.accuracy * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    appRoute(ResultsScreen(results: [result])),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _GuideView extends StatelessWidget {
  const _GuideView({required this.onStart});
  final ValueChanged<List<GameType>> onStart;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SmallTag('ANTES DE COMENZAR'),
      const SizedBox(height: 14),
      Text(
        'Conoce el reto.\nEncuentra tu estrategia.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 16),
      const Text(
        'Aquí se entrena concentración, precisión y velocidad. Aprende la dinámica y después ponla a prueba.',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 28),
      for (final type in GameType.practiceModes)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(gameIcon(type), color: gameColor(type)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        type.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(type.instructions),
                const SizedBox(height: 12),
                Text(
                  switch (type) {
                    GameType.memory => 'Consejo: agrupa los puntos por zonas. El patrón se oculta tras 2–3 segundos; selecciona las posiciones y confirma.',
                    GameType.grid => 'Resuelve una cuadrícula y memoriza el punto que parpadea a continuación. Al terminar el ciclo, toca los puntos en su orden de aparición. Las combinaciones son uniones de celdas.',
                    GameType.symmetry => 'Decide si las figuras son idénticas o si una refleja a la otra, según la consigna. Alterna cada pregunta con un flash de un punto y reconstruye el orden al final.',
                    GameType.switcher => 'Ejemplo: 1 3 4 2 toma la primera, tercera, cuarta y segunda ficha de la entrada. Aplica primero la regla superior y después elige la segunda.',
                    GameType.mixed => 'Comienza por un punto numerado de 3.5 s, resuelve Grid o Simetría en 5 s y repite 3 a 5 pares. Después marca el orden en 5 s sobre el mismo plano.',
                    GameType.strokes => 'Suma todos los trazos de los dos paneles. Solo una superposición exacta es válida: una línea ausente, adicional o desplazada cambia la respuesta a No.',
                    GameType.math => 'Ejemplo: 8 × 4 + 2 = 34. Toca las fichas en el orden deseado, usa cada ficha una vez y respeta la prioridad de × y ÷.',
                  },
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => onStart([type]),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Practicar este reto'),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 10),
      const SurfacePanel(
        color: AppColors.mint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu retroalimentación llega al final',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'Durante la ronda, la app registra las respuestas y avanza sin mostrar si acertaste. Al terminar encontrarás precisión, velocidad y una revisión de cada intento.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      const _Footer(),
    ],
  );
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.verified_user_outlined, size: 14, color: AppColors.muted),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'Herramienta de práctica independiente. Sin afiliación con P&G ni Aon. Los ejercicios son originales y no reproducen una evaluación oficial.',
          style: TextStyle(color: AppColors.muted, fontSize: 10, height: 1.6),
        ),
      ),
    ],
  );
}

Future<void> _gameInfo(
  BuildContext context,
  GameType type,
  VoidCallback onStart,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(type.title),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 140, child: GameArt(type: type)),
            const SizedBox(height: 16),
            Text(type.instructions),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
      FilledButton(
        onPressed: () {
          Navigator.pop(context);
          onStart();
        },
        child: const Text('Practicar'),
      ),
    ],
  ),
);

Future<void> _settings(BuildContext context) async {
  final store = context.read<AppStore>();
  var settings = store.settings;
  final result = await showDialog<TrainingSettings>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocalState) => AlertDialog(
        title: const Text('A tu medida'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ajusta tu próxima sesión de entrenamiento.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Duración de los demás juegos',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  direction:
                      MediaQuery.sizeOf(context).width < 380 ||
                          MediaQuery.textScalerOf(context).scale(14) > 20
                      ? Axis.vertical
                      : Axis.horizontal,
                  segments: const [
                    ButtonSegment(value: 5, label: Text('5 minutos')),
                    ButtonSegment(value: 6, label: Text('6 minutos')),
                  ],
                  selected: {settings.roundMinutes},
                  onSelectionChanged: (values) => setLocalState(
                    () => settings = settings.copyWith(
                      roundMinutes: values.single,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Grid + Memoria y Simetría + Memoria duran 3 minutos.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Nivel de dificultad',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                SegmentedButton<Difficulty>(
                  direction:
                      MediaQuery.sizeOf(context).width < 380 ||
                          MediaQuery.textScalerOf(context).scale(14) > 20
                      ? Axis.vertical
                      : Axis.horizontal,
                  segments: const [
                    ButtonSegment(
                      value: Difficulty.advanced,
                      label: Text('Avanzado'),
                    ),
                    ButtonSegment(
                      value: Difficulty.expert,
                      label: Text('Experto'),
                    ),
                  ],
                  selected: {settings.difficulty},
                  onSelectionChanged: (values) => setLocalState(
                    () =>
                        settings = settings.copyWith(difficulty: values.single),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Avanzado: comienza con 2 puntos y progresa hasta 5. Experto: comienza con 3 puntos, menos exposición y cálculos más largos.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Respuesta háptica',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Vibración suave al seleccionar, si tu dispositivo la admite.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  value: settings.haptics,
                  onChanged: (value) => setLocalState(
                    () => settings = settings.copyWith(haptics: value),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, settings),
            child: const Text('Guardar ajustes'),
          ),
        ],
      ),
    ),
  );
  if (result != null) await store.updateSettings(result);
}

Future<void> _clearHistory(BuildContext context) async {
  final store = context.read<AppStore>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Borrar tu historial?'),
      content: const Text(
        'Se eliminarán los resultados guardados en este dispositivo. Tus ajustes se conservarán.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Conservar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Borrar historial'),
        ),
      ],
    ),
  );
  if (confirmed == true) await store.clearHistory();
}
