import 'models.dart';
import 'question_generator.dart';

/// Pure phase graph. Timers and scoring belong to RoundController.
class MixedSequenceController {
  MixedSequenceController({
    required this.type,
    required this.difficulty,
    required this.generator,
  }) {
    if (![
      GameType.memory,
      GameType.grid,
      GameType.symmetry,
      GameType.mixed,
    ].contains(type)) {
      throw ArgumentError('Este juego no admite secuencias de puntos.');
    }
    _startCycle();
  }
  final GameType type;
  final Difficulty difficulty;
  final QuestionGenerator generator;
  late MemorySequenceQuestion _memory;
  late Question _question;
  var _phase = MixedPhase.flash;
  var _index = 0;
  var _cycleNumber = 0;
  var _reasoningNumber = 0;
  static const pointDuration = Duration(milliseconds: 3500);
  static const responseDuration = Duration(seconds: 5);
  MixedPhase get phase => _phase;
  Question get currentQuestion => _question;
  MemorySequenceQuestion get memory => _memory;
  int get index => _index;
  int get cycleNumber => _cycleNumber;
  Duration get flashDuration => pointDuration;
  Duration get phaseDuration =>
      _phase == MixedPhase.flash ? pointDuration : responseDuration;
  GameType get reasoningType => type == GameType.mixed
      ? (_reasoningNumber.isEven ? GameType.grid : GameType.symmetry)
      : type;
  void _startCycle() {
    _cycleNumber++;
    _index = 0;
    _memory = generator.generateMemorySequence(
      difficulty,
      cycleNumber: _cycleNumber,
    );
    _startPoint();
  }

  void _startPoint() {
    _phase = MixedPhase.flash;
    _question = PointFlashQuestion(
      memory: _memory,
      index: _index,
      durationMilliseconds: pointDuration.inMilliseconds,
    );
  }

  void _afterReasoning() {
    if (_index + 1 == _memory.sequence.length) {
      _phase = MixedPhase.recall;
      _question = _memory;
    } else {
      _index++;
      _startPoint();
    }
  }

  bool answer() {
    if (_phase == MixedPhase.flash) return false;
    if (_phase == MixedPhase.recall) {
      _startCycle();
    } else {
      _reasoningNumber++;
      _afterReasoning();
    }
    return true;
  }

  bool finishFlash() {
    if (_phase != MixedPhase.flash) return false;
    if (type == GameType.memory) {
      _afterReasoning();
    } else {
      _phase = MixedPhase.reasoning;
      _question = generator.generate(
        reasoningType,
        difficulty,
        questionNumber: _reasoningNumber + 1,
      );
    }
    return true;
  }
}
