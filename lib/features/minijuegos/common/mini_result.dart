import 'package:flutter/foundation.dart';

import '../../../domain/models.dart';

enum MiniGame { switchV2, progressive, chimp, mixed }

extension MiniGameDetails on MiniGame {
  String get title => switch (this) {
    MiniGame.switchV2 => 'Switch Challenge V2',
    MiniGame.progressive => 'Memoria progresiva',
    MiniGame.chimp => 'Chimp Test',
    MiniGame.mixed => 'Mixto V2',
  };
  String get description => switch (this) {
    MiniGame.switchV2 => 'Transforma figuras con dos filtros de posiciones.',
    MiniGame.progressive => 'Empieza con 3 elementos y supera niveles.',
    MiniGame.chimp => 'Memoriza de 6 a 9 números durante 2.5 segundos.',
    MiniGame.mixed =>
      'Puntos de 3.5 s, figuras de 5 s y recuperación ordenada.',
  };
  String get instructions => switch (this) {
    MiniGame.switchV2 => 'Sigue las figuras al primer filtro central. Elige el segundo filtro que produce la fila inferior. Mantén una opción pulsada para ver su transformación; suelta para responder.',
    MiniGame.progressive => 'Memoriza los números durante 2.5 segundos. Después toca sus posiciones en orden ascendente. Empiezas con 3 elementos y cada nivel agrega uno. Al superar el nivel 6 obtienes una segunda oportunidad.',
    MiniGame.chimp => 'Observa números sin cuadros durante exactamente 2.5 segundos. Cuando se conviertan en cuadros blancos, toca las posiciones de 1, 2, 3… El tamaño progresa de 6 a 9 números en seis rondas.',
    MiniGame.mixed => 'Primero verás un punto rojo numerado durante 3.5 s con desvanecimientos de 0.5 s. Después tienes 5 s para responder Sí/No a Grid o Simetría. Se repite 3, 4 o 5 pares y al final tienes 5 s para tocar los puntos en orden sobre la misma plantilla. Los plazos vencidos avanzan automáticamente.',
  };
}

@immutable
class MiniRoundResult {
  MiniRoundResult({
    required this.game,
    required this.startedAt,
    required this.duration,
    required Iterable<Attempt> attempts,
  }) : attempts = List.unmodifiable(attempts);
  final MiniGame game;
  final DateTime startedAt;
  final Duration duration;
  final List<Attempt> attempts;
  int get correctCount => attempts.where((a) => a.correct).length;
  Map<String, Object?> toJson() => {
    'game': game.name,
    'startedAt': startedAt.toIso8601String(),
    'durationUs': duration.inMicroseconds,
    'attempts': attempts.map((a) => a.toJson()).toList(),
  };
  factory MiniRoundResult.fromJson(Map<String, dynamic> json) =>
      MiniRoundResult(
        game: MiniGame.values.byName(json['game'] as String),
        startedAt: DateTime.parse(json['startedAt'] as String),
        duration: Duration(microseconds: (json['durationUs'] as num).toInt()),
        attempts: (json['attempts'] as List).map(
          (a) => Attempt.fromJson(Map<String, dynamic>.from(a as Map)),
        ),
      );
}

@immutable
class MiniSessionResult {
  MiniSessionResult({
    required this.date,
    required Iterable<MiniRoundResult> rounds,
  }) : rounds = List.unmodifiable(rounds);
  final DateTime date;
  final List<MiniRoundResult> rounds;
  List<Attempt> get attempts =>
      List.unmodifiable(rounds.expand((r) => r.attempts));
  int get correctCount => rounds.fold(0, (sum, r) => sum + r.correctCount);
  double get accuracy => attempts.isEmpty ? 0 : correctCount / attempts.length;
  Duration get duration =>
      rounds.fold(Duration.zero, (sum, r) => sum + r.duration);
  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'rounds': rounds.map((r) => r.toJson()).toList(),
  };
  factory MiniSessionResult.fromJson(Map<String, dynamic> json) =>
      MiniSessionResult(
        date: DateTime.parse(json['date'] as String),
        rounds: (json['rounds'] as List).map(
          (r) => MiniRoundResult.fromJson(Map<String, dynamic>.from(r as Map)),
        ),
      );
}
