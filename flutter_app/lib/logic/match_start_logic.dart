import '../domain/models/shogi_models.dart';

class MatchStartLogic {
  static const int furigomaPieceCount = 5;
  static const Duration furigomaRevealStep = Duration(milliseconds: 220);
  static const Duration furigomaRevealTail = Duration(milliseconds: 180);
  static const Duration furigomaResultHold = Duration(milliseconds: 1200);
  static const Duration furigomaSpinInterval = Duration(milliseconds: 90);
  static const Duration matchStartCueDuration = Duration(milliseconds: 1200);

  static bool shouldUseFurigoma(GameHandicap handicap) {
    return handicap == GameHandicap.none;
  }

  static ShogiPlayer defaultOpeningTurn(GameHandicap handicap) {
    return ShogiPlayer.sente;
  }

  static List<bool> randomFurigomaResults() {
    return List<bool>.generate(furigomaPieceCount, (_) => _randomBit());
  }

  static Duration revealDelayAt(int index) {
    return Duration(milliseconds: furigomaRevealStep.inMilliseconds * (index + 1));
  }

  static Duration revealFinishedDelay(int pieceCount) {
    return Duration(
      milliseconds: furigomaRevealStep.inMilliseconds * pieceCount + furigomaRevealTail.inMilliseconds,
    );
  }

  static ShogiPlayer openingTurnFrom(List<bool> furigomaResults) {
    final toCount = furigomaResults.where((value) => value).length;
    final fuCount = furigomaResults.length - toCount;
    return fuCount > toCount ? ShogiPlayer.sente : ShogiPlayer.gote;
  }

  static String furigomaSummary(List<bool> results) {
    final toCount = results.where((value) => value).length;
    final fuCount = results.length - toCount;
    return '振り駒（歩$fuCount・と$toCount）';
  }

  static bool _randomBit() {
    return DateTime.now().microsecondsSinceEpoch.isEven;
  }
}