import '../domain/models/shogi_models.dart';
import '../logic/game_engine.dart';

class KifuParseResult {
  const KifuParseResult({
    required this.playerSente,
    required this.playerGote,
    required this.resultSummary,
    required this.record,
  });

  final String playerSente;
  final String playerGote;
  final String resultSummary;
  final PersistedShogiGameRecord record;
}

class KifuParseException implements Exception {
  const KifuParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class KifuParser {
  static KifuParseResult parse({
    required String text,
    int? upToMoveCount,
    bool includeHistory = true,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const KifuParseException('棋譜テキストが空です');
    }
    if (_isCsaFormat(trimmed)) {
      return _parseCsa(trimmed, upToMoveCount: upToMoveCount, includeHistory: includeHistory);
    }
    return _parseKif(trimmed, upToMoveCount: upToMoveCount, includeHistory: includeHistory);
  }

  static bool _isCsaFormat(String text) {
    return text.startsWith('V2') || text.startsWith('+') && text.contains('FU');
  }

  static KifuParseResult _parseKif(
    String text, {
    int? upToMoveCount,
    required bool includeHistory,
  }) {
    final lines = text.split('\n');
    var playerSente = '先手';
    var playerGote = '後手';
    var resultSummary = '不明';
    var handicap = GameHandicap.none;
    ShogiPlayer? endGameWinner;
    var endGameReason = '';
    var isSennichite = false;
    var isInterrupted = false;
    var gameDate = DateTime.now();
    final headers = <String, String>{};
    final commentsByMove = <int, List<String>>{};
    final timeTextByMove = <int, String>{};
    final variations = <KifVariationBlock>[];
    final rawMoves = <({int number, String text, ShogiPlayer player})>[];
    int? currentVariationFromMove;
    final currentVariationLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      final separatorIndex = _firstHeaderSeparatorIndex(trimmed);
      if (separatorIndex != -1) {
        final key = trimmed.substring(0, separatorIndex).trim();
        final value = trimmed.substring(separatorIndex + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          headers[key] = value;
        }
      }
      playerSente = _headerValue(trimmed, '先手') ?? _headerValue(trimmed, '下手') ?? playerSente;
      playerGote = _headerValue(trimmed, '後手') ?? _headerValue(trimmed, '上手') ?? playerGote;
      resultSummary = _headerValue(trimmed, '結果') ?? resultSummary;
      final dateValue = _headerValue(trimmed, '開始日時');
      if (dateValue != null) {
        gameDate = _parseDateString(dateValue) ?? gameDate;
      }
      final handicapValue = _headerValue(trimmed, '手合割');
      if (handicapValue != null) {
        handicap = _handicapFromKif(handicapValue);
      }
    }

    for (final line in lines) {
      final trimmed = line.trim();
      final variationFrom = _variationStartMove(trimmed);
      if (variationFrom != null) {
        if (currentVariationFromMove != null) {
          variations.add(KifVariationBlock(fromMove: currentVariationFromMove, lines: List.of(currentVariationLines)));
        }
        currentVariationFromMove = variationFrom;
        currentVariationLines.clear();
        continue;
      }
      if (currentVariationFromMove != null) {
        if (trimmed.isNotEmpty) {
          currentVariationLines.add(trimmed);
        }
        continue;
      }
      if (trimmed.startsWith('*')) {
        final comment = trimmed.substring(1).trim();
        if (comment.isNotEmpty) {
          final targetMove = rawMoves.isEmpty ? 0 : rawMoves.last.number;
          commentsByMove.putIfAbsent(targetMove, () => <String>[]).add(comment);
        }
        continue;
      }
      if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith('&')) {
        continue;
      }

      final digitMatch = RegExp(r'^\d+').firstMatch(trimmed);
      if (digitMatch == null) {
        continue;
      }
      final number = int.parse(digitMatch.group(0)!);
      final afterNum = trimmed.substring(digitMatch.end).trim();
      if (afterNum.isEmpty) {
        continue;
      }
      final timeText = _extractKifTimeText(afterNum);
      if (timeText != null) {
        timeTextByMove[number] = timeText;
      }
      final moveText = afterNum.split(' (').first.trim();

      if (_isTerminalMarker(moveText)) {
        final lastPlayer = number.isEven ? ShogiPlayer.sente : ShogiPlayer.gote;
        switch (true) {
          case true when moveText.startsWith('投了'):
            endGameWinner = lastPlayer.opposite;
            endGameReason = '投了';
            resultSummary = '${endGameWinner.label}の勝ち（投了）';
          case true when moveText.startsWith('詰み'):
            endGameWinner = lastPlayer.opposite;
            endGameReason = '詰み';
            resultSummary = '${endGameWinner.label}の勝ち（詰み）';
          case true when moveText.startsWith('入玉勝ち'):
            endGameWinner = lastPlayer;
            endGameReason = '入玉勝ち';
            resultSummary = '${endGameWinner.label}の勝ち（入玉勝ち）';
          case true when moveText.startsWith('反則勝ち'):
            endGameWinner = lastPlayer;
            endGameReason = '反則勝ち';
            resultSummary = '${endGameWinner.label}の勝ち（反則）';
          case true when moveText.startsWith('反則負け'):
            endGameWinner = lastPlayer.opposite;
            endGameReason = '反則負け';
            resultSummary = '${endGameWinner.label}の勝ち（反則）';
          case true when moveText.startsWith('TIME_UP') || moveText.startsWith('切れ負け'):
            endGameWinner = lastPlayer.opposite;
            endGameReason = '時間切れ';
            resultSummary = '${endGameWinner.label}の勝ち（時間切れ）';
          case true when moveText.startsWith('反則'):
            endGameWinner = lastPlayer.opposite;
            endGameReason = '反則';
            resultSummary = '${endGameWinner.label}の勝ち（反則）';
          case true when moveText.startsWith('持将棋'):
            isInterrupted = true;
            resultSummary = '持将棋（引き分け）';
          case true when moveText.startsWith('千日手'):
            isSennichite = true;
            resultSummary = '千日手（引き分け）';
          default:
            isInterrupted = true;
            resultSummary = '対局中断';
        }
        break;
      }

      if (number != rawMoves.length + 1) {
        continue;
      }
      rawMoves.add((
        number: number,
        text: moveText,
        player: number.isOdd ? ShogiPlayer.sente : ShogiPlayer.gote,
      ));
    }

    if (currentVariationFromMove != null) {
      variations.add(KifVariationBlock(fromMove: currentVariationFromMove, lines: List.of(currentVariationLines)));
    }

    return _executeMoves(
      rawMoves: rawMoves.map((move) => (text: move.text, player: move.player)).toList(),
      handicap: handicap,
      endGameWinner: endGameWinner,
      endGameReason: endGameReason,
      isSennichite: isSennichite,
      isInterrupted: isInterrupted,
      resultSummary: resultSummary,
      playerSente: playerSente,
      playerGote: playerGote,
      gameDate: gameDate,
      isKif: true,
      extendedData: KifExtendedData(
        headers: headers,
        commentsByMove: commentsByMove,
        timeTextByMove: timeTextByMove,
        variations: variations,
      ),
      upToMoveCount: upToMoveCount,
      includeHistory: includeHistory,
    );
  }

  static KifuParseResult _parseCsa(
    String text, {
    int? upToMoveCount,
    required bool includeHistory,
  }) {
    final lines = text.split('\n');
    var playerSente = '先手';
    var playerGote = '後手';
    var resultSummary = '不明';
    ShogiPlayer? endGameWinner;
    var endGameReason = '';
    var isSennichite = false;
    var isInterrupted = false;
    final rawMoves = <({String text, ShogiPlayer player})>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed.startsWith('N+')) {
        playerSente = trimmed.substring(2);
      } else if (trimmed.startsWith('N-')) {
        playerGote = trimmed.substring(2);
      } else if (trimmed.startsWith('+') || trimmed.startsWith('-')) {
        rawMoves.add((
          text: trimmed,
          player: trimmed.startsWith('+') ? ShogiPlayer.sente : ShogiPlayer.gote,
        ));
      } else if (trimmed.startsWith('%')) {
        final lastPlayer = rawMoves.length.isEven ? ShogiPlayer.gote : ShogiPlayer.sente;
        if (trimmed.startsWith('%TORYO')) {
          endGameWinner = lastPlayer.opposite;
          endGameReason = '投了';
          resultSummary = '${endGameWinner.label}の勝ち（投了）';
        } else if (trimmed.startsWith('%TSUMI')) {
          endGameWinner = lastPlayer;
          endGameReason = '詰み';
          resultSummary = '${endGameWinner.label}の勝ち（詰み）';
        } else if (trimmed.startsWith('%KACHI')) {
          endGameWinner = lastPlayer;
          endGameReason = '入玉勝ち宣言';
          resultSummary = '${endGameWinner.label}の勝ち（入玉勝ち宣言）';
        } else if (trimmed.startsWith('%ILLEGAL_MOVE')) {
          endGameWinner = lastPlayer.opposite;
          endGameReason = '反則';
          resultSummary = '${endGameWinner.label}の勝ち（反則）';
        } else if (trimmed.startsWith('%TIME_UP')) {
          endGameWinner = lastPlayer.opposite;
          endGameReason = '時間切れ';
          resultSummary = '${endGameWinner.label}の勝ち（時間切れ）';
        } else if (trimmed.startsWith('%SENNICHITE')) {
          isSennichite = true;
          resultSummary = '千日手（引き分け）';
        } else if (trimmed.startsWith('%JISHOGI')) {
          isInterrupted = true;
          resultSummary = '持将棋（引き分け）';
        } else if (trimmed.startsWith('%MAX_MOVES') || trimmed.startsWith('%HIKIWAKE')) {
          isInterrupted = true;
          resultSummary = '引き分け（最大手数）';
        } else if (trimmed.startsWith('%CHUDAN')) {
          isInterrupted = true;
          resultSummary = '対局中断';
        }
        break;
      }
    }

    return _executeMoves(
      rawMoves: rawMoves,
      handicap: GameHandicap.none,
      endGameWinner: endGameWinner,
      endGameReason: endGameReason,
      isSennichite: isSennichite,
      isInterrupted: isInterrupted,
      resultSummary: resultSummary,
      playerSente: playerSente,
      playerGote: playerGote,
      gameDate: DateTime.now(),
      isKif: false,
      extendedData: null,
      upToMoveCount: upToMoveCount,
      includeHistory: includeHistory,
    );
  }

  static KifuParseResult _executeMoves({
    required List<({String text, ShogiPlayer player})> rawMoves,
    required GameHandicap handicap,
    required ShogiPlayer? endGameWinner,
    required String endGameReason,
    required bool isSennichite,
    required bool isInterrupted,
    required String resultSummary,
    required String playerSente,
    required String playerGote,
    required DateTime gameDate,
    required bool isKif,
    required KifExtendedData? extendedData,
    required int? upToMoveCount,
    required bool includeHistory,
  }) {
    var board = GameEngine.initialBoard(handicap: handicap);
    var senteHand = <ShogiPieceType, int>{};
    var goteHand = <ShogiPieceType, int>{};
    var moveRecords = <String>[];
    var moveHistory = <ShogiGameSnapshot>[];
    final effectiveMoveCount = (upToMoveCount ?? rawMoves.length).clamp(0, rawMoves.length);
    final effectiveRawMoves = rawMoves.take(effectiveMoveCount).toList();
    final reachedFinalMove = effectiveMoveCount == rawMoves.length;

    if (includeHistory) {
      moveHistory.add(_makeSnapshot(
        board: board,
        senteHand: senteHand,
        goteHand: goteHand,
        turn: ShogiPlayer.sente,
        winner: null,
        winReason: '',
        isSennichite: false,
        isInterrupted: false,
        positionCounts: const {},
        moveRecords: const [],
      ));
    }

    ({int row, int col})? lastDest;
    for (var index = 0; index < effectiveRawMoves.length; index++) {
      final move = effectiveRawMoves[index];
      final isLast = reachedFinalMove && index == effectiveRawMoves.length - 1;
      final parsedMove = isKif
          ? _parseKifMoveText(move.text, lastDest)
          : _parseCsaMoveText(move.text, move.player);
      if (parsedMove == null) {
        continue;
      }
      final applied = _applyMove(
        move: parsedMove,
        board: board,
        senteHand: senteHand,
        goteHand: goteHand,
        player: move.player,
      );
      board = applied.board;
      senteHand = applied.senteHand;
      goteHand = applied.goteHand;
      moveRecords = [...moveRecords, applied.record];
      lastDest = (row: parsedMove.toRow, col: parsedMove.toCol);

      final snapshot = _makeSnapshot(
        board: board,
        senteHand: senteHand,
        goteHand: goteHand,
        turn: move.player.opposite,
        winner: isLast ? endGameWinner : null,
        winReason: isLast ? endGameReason : '',
        isSennichite: isLast ? isSennichite : false,
        isInterrupted: isLast ? isInterrupted : false,
        positionCounts: const {},
        moveRecords: moveRecords,
      );
      if (includeHistory) {
        moveHistory.add(snapshot);
      }
    }

    final finalSnapshot = moveHistory.isNotEmpty
        ? moveHistory.last
        : _makeSnapshot(
            board: board,
            senteHand: senteHand,
            goteHand: goteHand,
            turn: effectiveRawMoves.isEmpty ? ShogiPlayer.sente : effectiveRawMoves.last.player.opposite,
            winner: reachedFinalMove ? endGameWinner : null,
            winReason: reachedFinalMove ? endGameReason : '',
            isSennichite: reachedFinalMove ? isSennichite : false,
            isInterrupted: reachedFinalMove ? isInterrupted : false,
            positionCounts: const {},
            moveRecords: moveRecords,
          );

    return KifuParseResult(
      playerSente: playerSente,
      playerGote: playerGote,
      resultSummary: resultSummary,
      record: PersistedShogiGameRecord(
        snapshot: finalSnapshot,
        moveHistory: includeHistory && moveHistory.isNotEmpty ? moveHistory.sublist(0, moveHistory.length - 1) : null,
        savedAt: gameDate,
        kifExtendedData: extendedData,
      ),
    );
  }

  static _ParsedMove? _parseKifMoveText(String text, ({int row, int col})? lastDest) {
    final chars = text.split('');
    var index = 0;
    late int toRow;
    late int toCol;

    if (index < chars.length && chars[index] == '同') {
      if (lastDest == null) {
        return null;
      }
      toRow = lastDest.row;
      toCol = lastDest.col;
      index += 1;
      while (index < chars.length && (chars[index] == ' ' || chars[index] == '　')) {
        index += 1;
      }
    } else if (index + 1 < chars.length) {
      final col = _fullWidthDigit(chars[index]);
      final row = _kanjiRow(chars[index + 1]);
      if (col == null || row == null) {
        return null;
      }
      toCol = 9 - col;
      toRow = row - 1;
      index += 2;
    } else {
      return null;
    }

    final tail = chars.sublist(index).join();
    final match = _pieceSymbolPrefix(tail);
    if (match == null) {
      return null;
    }
    index += match.length;
    final remainder = index < chars.length ? chars.sublist(index).join() : '';
    final isDrop = remainder.contains('打');
    var promote = false;
    int? fromRow;
    int? fromCol;

    final coordMatch = RegExp(r'\((\d{2})\)').firstMatch(remainder);
    if (coordMatch != null) {
      final coord = coordMatch.group(1)!;
      final fcKif = int.parse(coord[0]);
      final frKif = int.parse(coord[1]);
      fromCol = 9 - fcKif;
      fromRow = frKif - 1;
    }
    if (remainder.contains('不成')) {
      promote = false;
    } else if (remainder.contains('成')) {
      promote = true;
    }

    return _ParsedMove(
      toRow: toRow,
      toCol: toCol,
      fromRow: fromRow,
      fromCol: fromCol,
      isDrop: isDrop,
      promote: promote,
      parsedPieceType: match.type,
      parsedIsPromoted: match.isPromoted,
    );
  }

  static _ParsedMove? _parseCsaMoveText(String text, ShogiPlayer player) {
    var source = text.trim();
    if (source.length < 7) {
      return null;
    }
    source = source.substring(1);
    final chars = source.split('');
    final fcKif = int.tryParse(chars[0]);
    final frKif = int.tryParse(chars[1]);
    final tcKif = int.tryParse(chars[2]);
    final trKif = int.tryParse(chars[3]);
    if (fcKif == null || frKif == null || tcKif == null || trKif == null) {
      return null;
    }
    final pieceCode = chars.sublist(4, 6).join();
    final piece = _csaPieceCode(pieceCode);
    if (piece == null) {
      return null;
    }
    final isDrop = fcKif == 0 && frKif == 0;
    return _ParsedMove(
      toRow: trKif - 1,
      toCol: 9 - tcKif,
      fromRow: isDrop ? null : frKif - 1,
      fromCol: isDrop ? null : 9 - fcKif,
      isDrop: isDrop,
      promote: false,
      parsedPieceType: piece.type,
      parsedIsPromoted: piece.isPromoted,
    );
  }

  static ({
    List<List<ShogiPiece?>> board,
    Map<ShogiPieceType, int> senteHand,
    Map<ShogiPieceType, int> goteHand,
    String record,
  }) _applyMove({
    required _ParsedMove move,
    required List<List<ShogiPiece?>> board,
    required Map<ShogiPieceType, int> senteHand,
    required Map<ShogiPieceType, int> goteHand,
    required ShogiPlayer player,
  }) {
    final newBoard = board.map((row) => List<ShogiPiece?>.from(row)).toList();
    final newSenteHand = <ShogiPieceType, int>{...senteHand};
    final newGoteHand = <ShogiPieceType, int>{...goteHand};
    if (!GameEngine.isInside(move.toRow, move.toCol)) {
      return (board: newBoard, senteHand: newSenteHand, goteHand: newGoteHand, record: '?');
    }
    final to = BoardSquare(row: move.toRow, col: move.toCol);
    if (move.isDrop) {
      newBoard[to.row][to.col] = ShogiPiece(owner: player, type: move.parsedPieceType);
      final hand = player == ShogiPlayer.sente ? newSenteHand : newGoteHand;
      final remaining = (hand[move.parsedPieceType] ?? 0) - 1;
      if (remaining <= 0) {
        hand.remove(move.parsedPieceType);
      } else {
        hand[move.parsedPieceType] = remaining;
      }
      return (
        board: newBoard,
        senteHand: newSenteHand,
        goteHand: newGoteHand,
        record: GameEngine.formatDropRecord(player: player, type: move.parsedPieceType, to: to),
      );
    }

    if (move.fromRow == null || move.fromCol == null || !GameEngine.isInside(move.fromRow!, move.fromCol!)) {
      return (board: newBoard, senteHand: newSenteHand, goteHand: newGoteHand, record: '?');
    }

    final from = BoardSquare(row: move.fromRow!, col: move.fromCol!);
    final movingPiece = board[from.row][from.col] ?? ShogiPiece(
      owner: player,
      type: move.parsedPieceType,
      isPromoted: move.parsedIsPromoted,
    );
    final capturedPiece = board[to.row][to.col];
    if (capturedPiece != null) {
      final hand = player == ShogiPlayer.sente ? newSenteHand : newGoteHand;
      hand[capturedPiece.type] = (hand[capturedPiece.type] ?? 0) + 1;
    }

    newBoard[from.row][from.col] = null;
    newBoard[to.row][to.col] = move.promote
        ? movingPiece.copyWith(isPromoted: true)
        : movingPiece;

    return (
      board: newBoard,
      senteHand: newSenteHand,
      goteHand: newGoteHand,
      record: GameEngine.formatMoveRecord(
        player: player,
        piece: movingPiece,
        from: from,
        to: to,
        captured: capturedPiece,
        promote: move.promote,
      ),
    );
  }

  static ShogiGameSnapshot _makeSnapshot({
    required List<List<ShogiPiece?>> board,
    required Map<ShogiPieceType, int> senteHand,
    required Map<ShogiPieceType, int> goteHand,
    required ShogiPlayer turn,
    required ShogiPlayer? winner,
    required String winReason,
    required bool isSennichite,
    required bool isInterrupted,
    required Map<String, int> positionCounts,
    required List<String> moveRecords,
  }) {
    return ShogiGameSnapshot(
      board: board.map((row) => List<ShogiPiece?>.from(row)).toList(),
      selected: null,
      selectedDropType: null,
      senteHand: Map<ShogiPieceType, int>.from(senteHand),
      goteHand: Map<ShogiPieceType, int>.from(goteHand),
      pendingPromotionMove: null,
      turn: turn,
      winner: winner,
      winReason: winReason,
      isSennichite: isSennichite,
      isInterrupted: isInterrupted,
      positionCounts: Map<String, int>.from(positionCounts),
      moveRecords: List<String>.from(moveRecords),
    );
  }

  static bool _isTerminalMarker(String moveText) {
    const markers = [
      '投了',
      '中断',
      '詰み',
      '千日手',
      'TIME_UP',
      '反則',
      '持将棋',
      '入玉勝ち',
      '切れ負け',
    ];
    return markers.any(moveText.startsWith);
  }

  static String? _headerValue(String line, String key) {
    for (final separator in ['$key：', '$key:']) {
      if (line.startsWith(separator)) {
        final value = line.substring(separator.length).trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  static int _firstHeaderSeparatorIndex(String line) {
    final fullWidth = line.indexOf('：');
    if (fullWidth != -1) {
      return fullWidth;
    }
    return line.indexOf(':');
  }

  static int? _variationStartMove(String line) {
    if (!line.startsWith('変化：')) {
      return null;
    }
    final payload = line.replaceFirst('変化：', '');
    final match = RegExp(r'^\d+').firstMatch(payload);
    return match == null ? null : int.parse(match.group(0)!);
  }

  static String? _extractKifTimeText(String afterMoveText) {
    final match = RegExp(r'\(([^)]*/[^)]*)\)').firstMatch(afterMoveText);
    return match?.group(1)?.trim();
  }

  static GameHandicap _handicapFromKif(String value) {
    switch (value) {
      case '香落ち':
        return GameHandicap.lance;
      case '角落ち':
        return GameHandicap.bishop;
      case '飛車落ち':
        return GameHandicap.rook;
      case '二枚落ち':
        return GameHandicap.twoPieces;
      case '四枚落ち':
        return GameHandicap.fourPieces;
      case '六枚落ち':
        return GameHandicap.sixPieces;
      default:
        return GameHandicap.none;
    }
  }

  static DateTime? _parseDateString(String value) {
    final normalized = value.replaceAll('/', '-');
    final direct = DateTime.tryParse(normalized);
    if (direct != null) {
      return direct;
    }

    final westernMatch = RegExp(
      r'^(\d{4})[-](\d{1,2})[-](\d{1,2})(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$',
    ).firstMatch(normalized);
    if (westernMatch != null) {
      return DateTime(
        int.parse(westernMatch.group(1)!),
        int.parse(westernMatch.group(2)!),
        int.parse(westernMatch.group(3)!),
        int.parse(westernMatch.group(4) ?? '0'),
        int.parse(westernMatch.group(5) ?? '0'),
        int.parse(westernMatch.group(6) ?? '0'),
      );
    }

    final japaneseMatch = RegExp(
      r'^(\d{4})年(\d{1,2})月(\d{1,2})日(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$',
    ).firstMatch(value);
    if (japaneseMatch != null) {
      return DateTime(
        int.parse(japaneseMatch.group(1)!),
        int.parse(japaneseMatch.group(2)!),
        int.parse(japaneseMatch.group(3)!),
        int.parse(japaneseMatch.group(4) ?? '0'),
        int.parse(japaneseMatch.group(5) ?? '0'),
        int.parse(japaneseMatch.group(6) ?? '0'),
      );
    }

    return null;
  }

  static int? _fullWidthDigit(String char) {
    const digits = ['１', '２', '３', '４', '５', '６', '７', '８', '９'];
    final index = digits.indexOf(char);
    return index == -1 ? null : index + 1;
  }

  static int? _kanjiRow(String char) {
    const rows = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
    final index = rows.indexOf(char);
    return index == -1 ? null : index + 1;
  }

  static ({ShogiPieceType type, bool isPromoted, int length})? _pieceSymbolPrefix(String text) {
    const candidates = [
      ('成銀', ShogiPieceType.silver, true),
      ('成桂', ShogiPieceType.knight, true),
      ('成香', ShogiPieceType.lance, true),
      ('成歩', ShogiPieceType.pawn, true),
      ('王', ShogiPieceType.king, false),
      ('玉', ShogiPieceType.king, false),
      ('金', ShogiPieceType.gold, false),
      ('銀', ShogiPieceType.silver, false),
      ('桂', ShogiPieceType.knight, false),
      ('香', ShogiPieceType.lance, false),
      ('角', ShogiPieceType.bishop, false),
      ('飛', ShogiPieceType.rook, false),
      ('歩', ShogiPieceType.pawn, false),
      ('全', ShogiPieceType.silver, true),
      ('圭', ShogiPieceType.knight, true),
      ('杏', ShogiPieceType.lance, true),
      ('馬', ShogiPieceType.bishop, true),
      ('龍', ShogiPieceType.rook, true),
      ('竜', ShogiPieceType.rook, true),
      ('と', ShogiPieceType.pawn, true),
    ];
    for (final candidate in candidates) {
      if (text.startsWith(candidate.$1)) {
        return (type: candidate.$2, isPromoted: candidate.$3, length: candidate.$1.length);
      }
    }
    return null;
  }

  static ({ShogiPieceType type, bool isPromoted})? _csaPieceCode(String code) {
    switch (code) {
      case 'FU':
        return (type: ShogiPieceType.pawn, isPromoted: false);
      case 'KY':
        return (type: ShogiPieceType.lance, isPromoted: false);
      case 'KE':
        return (type: ShogiPieceType.knight, isPromoted: false);
      case 'GI':
        return (type: ShogiPieceType.silver, isPromoted: false);
      case 'KI':
        return (type: ShogiPieceType.gold, isPromoted: false);
      case 'KA':
        return (type: ShogiPieceType.bishop, isPromoted: false);
      case 'HI':
        return (type: ShogiPieceType.rook, isPromoted: false);
      case 'OU':
        return (type: ShogiPieceType.king, isPromoted: false);
      case 'TO':
        return (type: ShogiPieceType.pawn, isPromoted: true);
      case 'NY':
        return (type: ShogiPieceType.lance, isPromoted: true);
      case 'NK':
        return (type: ShogiPieceType.knight, isPromoted: true);
      case 'NG':
        return (type: ShogiPieceType.silver, isPromoted: true);
      case 'UM':
        return (type: ShogiPieceType.bishop, isPromoted: true);
      case 'RY':
        return (type: ShogiPieceType.rook, isPromoted: true);
      default:
        return null;
    }
  }
}

class _ParsedMove {
  const _ParsedMove({
    required this.toRow,
    required this.toCol,
    required this.fromRow,
    required this.fromCol,
    required this.isDrop,
    required this.promote,
    required this.parsedPieceType,
    required this.parsedIsPromoted,
  });

  final int toRow;
  final int toCol;
  final int? fromRow;
  final int? fromCol;
  final bool isDrop;
  final bool promote;
  final ShogiPieceType parsedPieceType;
  final bool parsedIsPromoted;
}