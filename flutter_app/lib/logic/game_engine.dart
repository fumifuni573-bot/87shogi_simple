import '../domain/models/shogi_models.dart';

class PositionRegistrationResult {
  const PositionRegistrationResult({required this.counts, required this.isSennichite});

  final Map<String, int> counts;
  final bool isSennichite;
}

class GameEngine {
  static bool isInside(int row, int col) => row >= 0 && row < 9 && col >= 0 && col < 9;

  static Map<String, int> initializePositionCountsIfNeeded({
    required Map<String, int> counts,
    required List<List<ShogiPiece?>> boardState,
    required Map<ShogiPieceType, int> senteHandState,
    required Map<ShogiPieceType, int> goteHandState,
    required ShogiPlayer sideToMove,
  }) {
    if (counts.isNotEmpty) {
      return counts;
    }
    final updated = <String, int>{...counts};
    final key = positionKey(
      boardState: boardState,
      senteHandState: senteHandState,
      goteHandState: goteHandState,
      sideToMove: sideToMove,
    );
    updated[key] = 1;
    return updated;
  }

  static PositionRegistrationResult registerPositionAndDetectSennichite({
    required Map<String, int> counts,
    required List<List<ShogiPiece?>> boardState,
    required Map<ShogiPieceType, int> senteHandState,
    required Map<ShogiPieceType, int> goteHandState,
    required ShogiPlayer sideToMove,
  }) {
    final updated = <String, int>{...counts};
    final key = positionKey(
      boardState: boardState,
      senteHandState: senteHandState,
      goteHandState: goteHandState,
      sideToMove: sideToMove,
    );
    final newCount = (updated[key] ?? 0) + 1;
    updated[key] = newCount;
    return PositionRegistrationResult(counts: updated, isSennichite: newCount >= 4);
  }

  static bool isGoldLikeMove({required int dr, required int dc, required int forward}) {
    const sideways = [
      (0, -1),
      (0, 1),
    ];
    final moves = <(int, int)>[
      (forward, -1),
      (forward, 0),
      (forward, 1),
      ...sideways,
      (-forward, 0),
    ];
    return moves.contains((dr, dc));
  }

  static bool isPromotionZone({required int row, required ShogiPlayer owner}) {
    return owner == ShogiPlayer.sente ? row <= 2 : row >= 6;
  }

  static bool isDeadEndRow(int row, ShogiPlayer owner) {
    return owner == ShogiPlayer.sente ? row == 0 : row == 8;
  }

  static bool isDeadEndKnightRow(int row, ShogiPlayer owner) {
    return owner == ShogiPlayer.sente ? row <= 1 : row >= 7;
  }

  static bool isPathClear({
    required List<List<ShogiPiece?>> boardState,
    required BoardSquare from,
    required BoardSquare to,
  }) {
    final dr = (to.row - from.row).sign;
    final dc = (to.col - from.col).sign;
    var row = from.row + dr;
    var col = from.col + dc;
    while (row != to.row || col != to.col) {
      if (boardState[row][col] != null) {
        return false;
      }
      row += dr;
      col += dc;
    }
    return true;
  }

  static String squareNotation(BoardSquare square) {
    const ranks = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
    return '${9 - square.col}${ranks[square.row]}';
  }

  static String formatMoveRecord({
    required ShogiPlayer player,
    required ShogiPiece piece,
    required BoardSquare from,
    required BoardSquare to,
    required ShogiPiece? captured,
    required bool promote,
  }) {
    final action = captured == null ? '→' : '×';
    final promoteText = promote && piece.type.canPromote ? '成' : '';
    return '${player.label} ${squareNotation(from)} ${piece.displaySymbol} $action ${squareNotation(to)}$promoteText';
  }

  static String formatDropRecord({
    required ShogiPlayer player,
    required ShogiPieceType type,
    required BoardSquare to,
  }) {
    return '${player.label} ${type.symbol} 打 ${squareNotation(to)}';
  }

  static String resultSummary(ShogiGameSnapshot snapshot) => snapshot.resultSummary;

  static String positionKey({
    required List<List<ShogiPiece?>> boardState,
    required Map<ShogiPieceType, int> senteHandState,
    required Map<ShogiPieceType, int> goteHandState,
    required ShogiPlayer sideToMove,
  }) {
    final buffer = StringBuffer(sideToMove == ShogiPlayer.sente ? 'S|' : 'G|');
    for (final row in boardState) {
      for (final piece in row) {
        if (piece == null) {
          buffer.write('___');
          continue;
        }
        final ownerCode = piece.owner == ShogiPlayer.sente ? 'S' : 'G';
        final promoCode = piece.isPromoted ? '+' : '-';
        buffer.write('$ownerCode${_pieceCode(piece.type)}$promoCode');
      }
    }
    buffer
      ..write('|')
      ..write(_handKey(senteHandState))
      ..write('|')
      ..write(_handKey(goteHandState));
    return buffer.toString();
  }

  static List<List<ShogiPiece?>> initialBoard({GameHandicap handicap = GameHandicap.none}) {
    final board = List.generate(9, (_) => List<ShogiPiece?>.filled(9, null));
    const backRow = [
      ShogiPieceType.lance,
      ShogiPieceType.knight,
      ShogiPieceType.silver,
      ShogiPieceType.gold,
      ShogiPieceType.king,
      ShogiPieceType.gold,
      ShogiPieceType.silver,
      ShogiPieceType.knight,
      ShogiPieceType.lance,
    ];

    for (var col = 0; col < 9; col++) {
      board[0][col] = ShogiPiece(owner: ShogiPlayer.gote, type: backRow[col]);
      board[2][col] = const ShogiPiece(owner: ShogiPlayer.gote, type: ShogiPieceType.pawn);
      board[6][col] = const ShogiPiece(owner: ShogiPlayer.sente, type: ShogiPieceType.pawn);
      board[8][col] = ShogiPiece(owner: ShogiPlayer.sente, type: backRow[col]);
    }

    board[1][1] = const ShogiPiece(owner: ShogiPlayer.gote, type: ShogiPieceType.rook);
    board[1][7] = const ShogiPiece(owner: ShogiPlayer.gote, type: ShogiPieceType.bishop);
    board[7][1] = const ShogiPiece(owner: ShogiPlayer.sente, type: ShogiPieceType.bishop);
    board[7][7] = const ShogiPiece(owner: ShogiPlayer.sente, type: ShogiPieceType.rook);

    switch (handicap) {
      case GameHandicap.none:
        break;
      case GameHandicap.lance:
        board[8][8] = null;
      case GameHandicap.bishop:
        board[7][1] = null;
      case GameHandicap.rook:
        board[7][7] = null;
      case GameHandicap.twoPieces:
        board[7][7] = null;
        board[7][1] = null;
      case GameHandicap.fourPieces:
        board[7][7] = null;
        board[7][1] = null;
        board[8][0] = null;
        board[8][8] = null;
      case GameHandicap.sixPieces:
        board[7][7] = null;
        board[7][1] = null;
        board[8][0] = null;
        board[8][8] = null;
        board[8][1] = null;
        board[8][7] = null;
    }

    return board;
  }

  static ShogiGameSnapshot initialSnapshot({GameHandicap handicap = GameHandicap.none}) {
    return ShogiGameSnapshot(
      board: initialBoard(handicap: handicap),
      selected: null,
      selectedDropType: null,
      senteHand: const {},
      goteHand: const {},
      pendingPromotionMove: null,
      turn: ShogiPlayer.sente,
      winner: null,
      winReason: '',
      isSennichite: false,
      isInterrupted: false,
      positionCounts: const {},
      moveRecords: const [],
    );
  }

  static String _handKey(Map<ShogiPieceType, int> hand) {
    return ShogiPieceType.handOrder.map((type) => '${_pieceCode(type)}${hand[type] ?? 0}').join(',');
  }

  static String _pieceCode(ShogiPieceType type) {
    switch (type) {
      case ShogiPieceType.king:
        return 'K';
      case ShogiPieceType.gold:
        return 'G';
      case ShogiPieceType.silver:
        return 'S';
      case ShogiPieceType.knight:
        return 'N';
      case ShogiPieceType.lance:
        return 'L';
      case ShogiPieceType.bishop:
        return 'B';
      case ShogiPieceType.rook:
        return 'R';
      case ShogiPieceType.pawn:
        return 'P';
    }
  }
}