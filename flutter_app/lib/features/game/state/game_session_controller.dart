import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/shogi_models.dart';
import '../../../logic/game_engine.dart';

class GameSessionState {
  const GameSessionState({
    required this.board,
    required this.senteHand,
    required this.goteHand,
    required this.suppressGameEndPopup,
    required this.showFurigomaCue,
    required this.furigomaResults,
    required this.furigomaRevealCount,
    required this.furigomaRouletteTick,
    required this.furigomaResultMessage,
    required this.selectedHandicap,
    required this.boardMotionTick,
    required this.showStartScreen,
    required this.showGameEndPopup,
    required this.isReviewMode,
    required this.showMatchStartCue,
    required this.selected,
    required this.selectedDropType,
    required this.pendingPromotionMove,
    required this.reviewIndex,
    required this.positionCounts,
    required this.moveHistory,
    required this.moveRecords,
    required this.turn,
    required this.winner,
    required this.winReason,
    required this.isSennichite,
    required this.isInterrupted,
    required this.statusMessage,
  });

  factory GameSessionState.initial() {
    return GameSessionState(
      board: GameEngine.initialBoard(),
      senteHand: const {},
      goteHand: const {},
      suppressGameEndPopup: false,
      showFurigomaCue: false,
      furigomaResults: List<bool>.filled(5, false),
      furigomaRevealCount: 0,
      furigomaRouletteTick: 0,
      furigomaResultMessage: '',
      selectedHandicap: GameHandicap.none,
      boardMotionTick: 0,
      showStartScreen: true,
      showGameEndPopup: false,
      isReviewMode: false,
      showMatchStartCue: false,
      selected: null,
      selectedDropType: null,
      pendingPromotionMove: null,
      reviewIndex: 0,
      positionCounts: const {},
      moveHistory: const [],
      moveRecords: const [],
      turn: ShogiPlayer.sente,
      winner: null,
      winReason: '詰み',
      isSennichite: false,
      isInterrupted: false,
      statusMessage: '駒を選んで移動してください',
    );
  }

  final List<List<ShogiPiece?>> board;
  final Map<ShogiPieceType, int> senteHand;
  final Map<ShogiPieceType, int> goteHand;
  final bool suppressGameEndPopup;
  final bool showFurigomaCue;
  final List<bool> furigomaResults;
  final int furigomaRevealCount;
  final int furigomaRouletteTick;
  final String furigomaResultMessage;
  final GameHandicap selectedHandicap;
  final int boardMotionTick;
  final bool showStartScreen;
  final bool showGameEndPopup;
  final bool isReviewMode;
  final bool showMatchStartCue;
  final BoardSquare? selected;
  final ShogiPieceType? selectedDropType;
  final PromotionPendingMove? pendingPromotionMove;
  final int reviewIndex;
  final Map<String, int> positionCounts;
  final List<ShogiGameSnapshot> moveHistory;
  final List<String> moveRecords;
  final ShogiPlayer turn;
  final ShogiPlayer? winner;
  final String winReason;
  final bool isSennichite;
  final bool isInterrupted;
  final String statusMessage;

  GameSessionState copyWith({
    List<List<ShogiPiece?>>? board,
    Map<ShogiPieceType, int>? senteHand,
    Map<ShogiPieceType, int>? goteHand,
    bool? suppressGameEndPopup,
    bool? showFurigomaCue,
    List<bool>? furigomaResults,
    int? furigomaRevealCount,
    int? furigomaRouletteTick,
    String? furigomaResultMessage,
    GameHandicap? selectedHandicap,
    int? boardMotionTick,
    bool? showStartScreen,
    bool? showGameEndPopup,
    bool? isReviewMode,
    bool? showMatchStartCue,
    BoardSquare? selected,
    bool clearSelected = false,
    ShogiPieceType? selectedDropType,
    bool clearSelectedDropType = false,
    PromotionPendingMove? pendingPromotionMove,
    bool clearPendingPromotionMove = false,
    int? reviewIndex,
    Map<String, int>? positionCounts,
    List<ShogiGameSnapshot>? moveHistory,
    List<String>? moveRecords,
    ShogiPlayer? turn,
    ShogiPlayer? winner,
    bool clearWinner = false,
    String? winReason,
    bool? isSennichite,
    bool? isInterrupted,
    String? statusMessage,
  }) {
    return GameSessionState(
      board: board ?? this.board,
      senteHand: senteHand ?? this.senteHand,
      goteHand: goteHand ?? this.goteHand,
      suppressGameEndPopup: suppressGameEndPopup ?? this.suppressGameEndPopup,
      showFurigomaCue: showFurigomaCue ?? this.showFurigomaCue,
      furigomaResults: furigomaResults ?? this.furigomaResults,
      furigomaRevealCount: furigomaRevealCount ?? this.furigomaRevealCount,
      furigomaRouletteTick: furigomaRouletteTick ?? this.furigomaRouletteTick,
      furigomaResultMessage: furigomaResultMessage ?? this.furigomaResultMessage,
      selectedHandicap: selectedHandicap ?? this.selectedHandicap,
      boardMotionTick: boardMotionTick ?? this.boardMotionTick,
      showStartScreen: showStartScreen ?? this.showStartScreen,
      showGameEndPopup: showGameEndPopup ?? this.showGameEndPopup,
      isReviewMode: isReviewMode ?? this.isReviewMode,
      showMatchStartCue: showMatchStartCue ?? this.showMatchStartCue,
      selected: clearSelected ? null : (selected ?? this.selected),
      selectedDropType: clearSelectedDropType ? null : (selectedDropType ?? this.selectedDropType),
      pendingPromotionMove: clearPendingPromotionMove
          ? null
          : (pendingPromotionMove ?? this.pendingPromotionMove),
      reviewIndex: reviewIndex ?? this.reviewIndex,
      positionCounts: positionCounts ?? this.positionCounts,
      moveHistory: moveHistory ?? this.moveHistory,
      moveRecords: moveRecords ?? this.moveRecords,
      turn: turn ?? this.turn,
      winner: clearWinner ? null : (winner ?? this.winner),
      winReason: winReason ?? this.winReason,
      isSennichite: isSennichite ?? this.isSennichite,
      isInterrupted: isInterrupted ?? this.isInterrupted,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class GameSessionController extends Notifier<GameSessionState> {
  @override
  GameSessionState build() => GameSessionState.initial();

  void resetSession({GameHandicap handicap = GameHandicap.none}) {
    final board = GameEngine.initialBoard(handicap: handicap);
    final counts = GameEngine.initializePositionCountsIfNeeded(
      counts: const {},
      boardState: board,
      senteHandState: const {},
      goteHandState: const {},
      sideToMove: ShogiPlayer.sente,
    );
    final initialSnapshot = ShogiGameSnapshot(
      board: _cloneBoard(board),
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
      positionCounts: counts,
      moveRecords: const [],
    );
    state = GameSessionState.initial().copyWith(
      board: board,
      selectedHandicap: handicap,
      positionCounts: counts,
      moveHistory: [initialSnapshot],
      moveRecords: const [],
      statusMessage: '駒を選んで移動してください',
    );
  }

  List<BoardSquare> currentLegalTargets() {
    if (_isGameOver(state) || state.isReviewMode) {
      return const [];
    }

    if (state.selectedDropType case final dropType?) {
      return _legalDropTargets(type: dropType, owner: state.turn);
    }

    final selected = state.selected;
    if (selected == null) {
      return const [];
    }

    final piece = state.board[selected.row][selected.col];
    if (piece == null || piece.owner != state.turn) {
      return const [];
    }

    final targets = <BoardSquare>[];
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        final to = BoardSquare(row: row, col: col);
        if (_isLegalMove(from: selected, to: to)) {
          targets.add(to);
        }
      }
    }
    return targets;
  }

  void toggleDropSelection(ShogiPieceType type) {
    if (state.isReviewMode) {
      state = state.copyWith(statusMessage: '検討モード中は局面移動か再開を選んでください');
      return;
    }

    final currentHand = _handForPlayer(state.turn);
    if ((currentHand[type] ?? 0) <= 0) {
      state = state.copyWith(
        clearSelectedDropType: true,
        statusMessage: 'その駒は持っていません',
      );
      return;
    }

    if (state.selectedDropType == type) {
      state = state.copyWith(
        clearSelected: true,
        clearSelectedDropType: true,
        statusMessage: '打つ駒の選択を解除しました',
      );
      return;
    }

    state = state.copyWith(
      clearSelected: true,
      selectedDropType: type,
      statusMessage: '${type.symbol}を打つ場所を選んでください',
    );
  }

  void handleBoardTap(BoardSquare tapped) {
    if (state.isReviewMode) {
      state = state.copyWith(statusMessage: _reviewStatusText(state.reviewIndex));
      return;
    }

    if (state.pendingPromotionMove != null) {
      state = state.copyWith(statusMessage: '成るかどうかを先に選んでください');
      return;
    }

    if (_isGameOver(state)) {
      state = state.copyWith(statusMessage: '対局終了中です。最初からを押してください');
      return;
    }

    final tappedPiece = state.board[tapped.row][tapped.col];

    if (state.selectedDropType case final dropType?) {
      _handleDrop(type: dropType, to: tapped);
      return;
    }

    final currentSelection = state.selected;
    if (currentSelection == null) {
      if (tappedPiece != null && tappedPiece.owner == state.turn) {
        state = state.copyWith(
          selected: tapped,
          clearSelectedDropType: true,
          statusMessage: '${tappedPiece.displaySymbol}を選択中',
        );
      } else {
        state = state.copyWith(statusMessage: '${state.turn.label}の駒を選んでください');
      }
      return;
    }

    if (_sameSquare(currentSelection, tapped)) {
      state = state.copyWith(clearSelected: true, statusMessage: '選択を解除しました');
      return;
    }

    if (tappedPiece != null && tappedPiece.owner == state.turn) {
      state = state.copyWith(
        selected: tapped,
        clearSelectedDropType: true,
        statusMessage: '${tappedPiece.displaySymbol}に選択を変更',
      );
      return;
    }

    if (!_isLegalMove(from: currentSelection, to: tapped)) {
      state = state.copyWith(statusMessage: 'その場所には移動できません');
      return;
    }

    final movingPiece = state.board[currentSelection.row][currentSelection.col];
    if (movingPiece == null) {
      state = state.copyWith(clearSelected: true, statusMessage: '移動元の駒が見つかりません');
      return;
    }

    final promotion = _promotionState(piece: movingPiece, from: currentSelection, to: tapped);

    if (promotion.canPromote && !promotion.mustPromote) {
      state = state.copyWith(
        pendingPromotionMove: PromotionPendingMove(from: currentSelection, to: tapped),
        statusMessage: '成るかどうかを選んでください',
      );
      return;
    }

    _executeMove(
      from: currentSelection,
      to: tapped,
      promote: promotion.mustPromote,
    );
  }

  void resolvePendingPromotion({required bool promote}) {
    final pending = state.pendingPromotionMove;
    if (pending == null) {
      return;
    }

    _executeMove(
      from: pending.from,
      to: pending.to,
      promote: promote,
    );
  }

  void cancelPendingPromotion() {
    if (state.pendingPromotionMove == null) {
      return;
    }

    state = state.copyWith(
      clearPendingPromotionMove: true,
      statusMessage: '成り選択をキャンセルしました。別の手を選べます',
    );
  }

  void dismissMatchStartCue() {
    if (!state.showMatchStartCue) {
      return;
    }

    state = state.copyWith(showMatchStartCue: false);
  }

  void dismissGameEndPopup() {
    if (!state.showGameEndPopup) {
      return;
    }

    state = state.copyWith(showGameEndPopup: false);
  }

  void returnToStartScreen() {
    state = state.copyWith(
      showStartScreen: true,
      showGameEndPopup: false,
      showMatchStartCue: false,
      clearSelected: true,
      clearSelectedDropType: true,
      clearPendingPromotionMove: true,
    );
  }

  void enterReviewMode() {
    if (state.moveHistory.isEmpty) {
      return;
    }

    final reviewIndex = state.moveHistory.length - 1;
    final snapshot = state.moveHistory[reviewIndex];
    _applySnapshot(
      snapshot,
      reviewIndex: reviewIndex,
      isReviewMode: true,
      suppressGameEndPopup: true,
      showGameEndPopup: false,
      statusMessage: _reviewStatusText(reviewIndex),
    );
  }

  void openPersistedRecordForReview(PersistedShogiGameRecord record) {
    final history = <ShogiGameSnapshot>[
      ...(record.moveHistory ?? const <ShogiGameSnapshot>[]),
      record.snapshot,
    ];
    if (history.isEmpty) {
      return;
    }

    final reviewIndex = history.length - 1;
    final snapshot = history[reviewIndex];
    state = GameSessionState.initial().copyWith(
      board: _cloneBoard(snapshot.board),
      senteHand: Map<ShogiPieceType, int>.from(snapshot.senteHand),
      goteHand: Map<ShogiPieceType, int>.from(snapshot.goteHand),
      clearSelected: true,
      clearSelectedDropType: true,
      clearPendingPromotionMove: true,
      turn: snapshot.turn,
      winner: snapshot.winner,
      clearWinner: snapshot.winner == null,
      winReason: snapshot.winReason,
      isSennichite: snapshot.isSennichite,
      isInterrupted: snapshot.isInterrupted,
      positionCounts: Map<String, int>.from(snapshot.positionCounts),
      moveRecords: List<String>.from(snapshot.moveRecords),
      moveHistory: history,
      reviewIndex: reviewIndex,
      isReviewMode: true,
      suppressGameEndPopup: true,
      showGameEndPopup: false,
      showStartScreen: false,
      showMatchStartCue: false,
      statusMessage: _reviewStatusText(reviewIndex),
    );
  }

  void moveReviewBy(int delta) {
    if (!state.isReviewMode || state.moveHistory.isEmpty) {
      return;
    }
    seekReview(state.reviewIndex + delta);
  }

  void seekReview(int index) {
    if (!state.isReviewMode || state.moveHistory.isEmpty) {
      return;
    }
    final normalized = index.clamp(0, state.moveHistory.length - 1);
    final snapshot = state.moveHistory[normalized];
    _applySnapshot(
      snapshot,
      reviewIndex: normalized,
      isReviewMode: true,
      suppressGameEndPopup: true,
      showGameEndPopup: false,
      statusMessage: _reviewStatusText(normalized),
    );
  }

  void goToReviewStart() {
    seekReview(0);
  }

  void goToReviewEnd() {
    if (state.moveHistory.isEmpty) {
      return;
    }
    seekReview(state.moveHistory.length - 1);
  }

  void resumeFromReview() {
    if (!state.isReviewMode || state.moveHistory.isEmpty) {
      return;
    }
    final snapshot = state.moveHistory[state.reviewIndex];
    final truncatedHistory = state.moveHistory.take(state.reviewIndex + 1).toList(growable: false);
    _applySnapshot(
      snapshot,
      reviewIndex: state.reviewIndex,
      isReviewMode: false,
      suppressGameEndPopup: false,
      showGameEndPopup: false,
      moveHistory: truncatedHistory,
      statusMessage: '${snapshot.turn.label}の手番です',
    );
  }

  void updateBoard(List<List<ShogiPiece?>> board) {
    state = state.copyWith(board: board, boardMotionTick: state.boardMotionTick + 1);
  }

  void updateHands({
    Map<ShogiPieceType, int>? senteHand,
    Map<ShogiPieceType, int>? goteHand,
  }) {
    state = state.copyWith(
      senteHand: senteHand ?? state.senteHand,
      goteHand: goteHand ?? state.goteHand,
    );
  }

  void setSelected(BoardSquare? square) {
    state = state.copyWith(selected: square, clearSelected: square == null);
  }

  void setSelectedDropType(ShogiPieceType? pieceType) {
    state = state.copyWith(
      selectedDropType: pieceType,
      clearSelectedDropType: pieceType == null,
    );
  }

  void setPendingPromotionMove(PromotionPendingMove? move) {
    state = state.copyWith(
      pendingPromotionMove: move,
      clearPendingPromotionMove: move == null,
    );
  }

  void setStatusMessage(String message) {
    state = state.copyWith(statusMessage: message);
  }

  void setTurn(ShogiPlayer turn) {
    state = state.copyWith(turn: turn);
  }

  void setMoveData({
    List<String>? moveRecords,
    List<ShogiGameSnapshot>? moveHistory,
    int? reviewIndex,
  }) {
    state = state.copyWith(
      moveRecords: moveRecords ?? state.moveRecords,
      moveHistory: moveHistory ?? state.moveHistory,
      reviewIndex: reviewIndex ?? state.reviewIndex,
    );
  }

  void setFlags({
    bool? showStartScreen,
    bool? showGameEndPopup,
    bool? isReviewMode,
    bool? showMatchStartCue,
    bool? showFurigomaCue,
    bool? suppressGameEndPopup,
  }) {
    state = state.copyWith(
      showStartScreen: showStartScreen ?? state.showStartScreen,
      showGameEndPopup: showGameEndPopup ?? state.showGameEndPopup,
      isReviewMode: isReviewMode ?? state.isReviewMode,
      showMatchStartCue: showMatchStartCue ?? state.showMatchStartCue,
      showFurigomaCue: showFurigomaCue ?? state.showFurigomaCue,
      suppressGameEndPopup: suppressGameEndPopup ?? state.suppressGameEndPopup,
    );
  }

  void setFurigomaState({
    List<bool>? results,
    int? revealCount,
    int? rouletteTick,
    String? resultMessage,
  }) {
    state = state.copyWith(
      furigomaResults: results ?? state.furigomaResults,
      furigomaRevealCount: revealCount ?? state.furigomaRevealCount,
      furigomaRouletteTick: rouletteTick ?? state.furigomaRouletteTick,
      furigomaResultMessage: resultMessage ?? state.furigomaResultMessage,
    );
  }

  void setResult({
    ShogiPlayer? winner,
    String? winReason,
    bool? isSennichite,
    bool? isInterrupted,
    bool clearWinner = false,
  }) {
    state = state.copyWith(
      winner: winner,
      clearWinner: clearWinner,
      winReason: winReason ?? state.winReason,
      isSennichite: isSennichite ?? state.isSennichite,
      isInterrupted: isInterrupted ?? state.isInterrupted,
    );
  }

  void setSelectedHandicap(GameHandicap handicap) {
    state = state.copyWith(selectedHandicap: handicap);
  }

  void resignCurrentPlayer() {
    if (_isGameOver(state) || state.isReviewMode) {
      return;
    }

    final resigningPlayer = state.turn;
    final winner = resigningPlayer.opposite;
    state = state.copyWith(
      winner: winner,
      winReason: '投了',
      isInterrupted: false,
      isSennichite: false,
      showGameEndPopup: true,
      clearSelected: true,
      clearSelectedDropType: true,
      clearPendingPromotionMove: true,
      statusMessage: '${resigningPlayer.label}が投了。${winner.label}の勝ちです',
    );
  }

  void setPositionCounts(Map<String, int> counts) {
    state = state.copyWith(positionCounts: counts);
  }

  String reviewStatusText() => _reviewStatusText(state.reviewIndex);

  int reviewMaxIndex() => state.moveHistory.isEmpty ? 0 : state.moveHistory.length - 1;

  PersistedShogiGameRecord buildPersistedRecord() {
    return PersistedShogiGameRecord(
      snapshot: ShogiGameSnapshot(
        board: _cloneBoard(state.board),
        selected: null,
        selectedDropType: null,
        senteHand: Map<ShogiPieceType, int>.from(state.senteHand),
        goteHand: Map<ShogiPieceType, int>.from(state.goteHand),
        pendingPromotionMove: null,
        turn: state.turn,
        winner: state.winner,
        winReason: state.winReason,
        isSennichite: state.isSennichite,
        isInterrupted: state.isInterrupted,
        positionCounts: Map<String, int>.from(state.positionCounts),
        moveRecords: List<String>.from(state.moveRecords),
      ),
      moveHistory: state.moveHistory.map((entry) => entry).toList(growable: false),
      savedAt: DateTime.now(),
      kifExtendedData: KifExtendedData(
        headers: {
          '先手': '先手',
          '後手': '後手',
          '手合割': _handicapLabel(state.selectedHandicap),
          '開始日時': _formatStartedAt(),
        },
      ),
    );
  }

  bool _isGameOver(GameSessionState state) {
    return state.winner != null || state.isInterrupted || state.isSennichite;
  }

  String _reviewStatusText(int index) {
    if (state.moveHistory.isEmpty) {
      return '検討モード';
    }
    if (index == 0) {
      return '検討モード: 初期局面';
    }
    if (index >= state.moveHistory.length - 1) {
      return '検討モード: 終局局面';
    }
    return '検討モード: $index手目';
  }

  String _handicapLabel(GameHandicap handicap) {
    switch (handicap) {
      case GameHandicap.none:
        return '平手';
      case GameHandicap.lance:
        return '香落ち';
      case GameHandicap.bishop:
        return '角落ち';
      case GameHandicap.rook:
        return '飛車落ち';
      case GameHandicap.twoPieces:
        return '二枚落ち';
      case GameHandicap.fourPieces:
        return '四枚落ち';
      case GameHandicap.sixPieces:
        return '六枚落ち';
    }
  }

  String _formatStartedAt() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}/${two(now.month)}/${two(now.day)} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  void _applySnapshot(
    ShogiGameSnapshot snapshot, {
    required int reviewIndex,
    required bool isReviewMode,
    required bool suppressGameEndPopup,
    required bool showGameEndPopup,
    required String statusMessage,
    List<ShogiGameSnapshot>? moveHistory,
  }) {
    state = state.copyWith(
      board: _cloneBoard(snapshot.board),
      senteHand: Map<ShogiPieceType, int>.from(snapshot.senteHand),
      goteHand: Map<ShogiPieceType, int>.from(snapshot.goteHand),
      clearSelected: true,
      clearSelectedDropType: true,
      clearPendingPromotionMove: true,
      turn: snapshot.turn,
      winner: snapshot.winner,
      clearWinner: snapshot.winner == null,
      winReason: snapshot.winReason,
      isSennichite: snapshot.isSennichite,
      isInterrupted: snapshot.isInterrupted,
      positionCounts: Map<String, int>.from(snapshot.positionCounts),
      moveRecords: List<String>.from(snapshot.moveRecords),
      moveHistory: moveHistory ?? state.moveHistory,
      reviewIndex: reviewIndex,
      isReviewMode: isReviewMode,
      suppressGameEndPopup: suppressGameEndPopup,
      showGameEndPopup: showGameEndPopup,
      showStartScreen: false,
      statusMessage: statusMessage,
    );
  }

  Map<ShogiPieceType, int> _handForPlayer(ShogiPlayer player) {
    return player == ShogiPlayer.sente ? state.senteHand : state.goteHand;
  }

  bool _sameSquare(BoardSquare left, BoardSquare right) {
    return left.row == right.row && left.col == right.col;
  }

  List<List<ShogiPiece?>> _cloneBoard(List<List<ShogiPiece?>> board) {
    return board.map((row) => List<ShogiPiece?>.of(row)).toList(growable: false);
  }

  bool _canMovePiece({
    required List<List<ShogiPiece?>> boardState,
    required BoardSquare from,
    required BoardSquare to,
  }) {
    if (!GameEngine.isInside(from.row, from.col) || !GameEngine.isInside(to.row, to.col)) {
      return false;
    }

    final piece = boardState[from.row][from.col];
    if (piece == null) {
      return false;
    }

    final dr = to.row - from.row;
    final dc = to.col - from.col;
    if (dr == 0 && dc == 0) {
      return false;
    }

    final destination = boardState[to.row][to.col];
    if (destination != null && destination.owner == piece.owner) {
      return false;
    }

    final forward = piece.owner.forward;

    if (piece.isPromoted) {
      switch (piece.type) {
        case ShogiPieceType.pawn:
        case ShogiPieceType.lance:
        case ShogiPieceType.knight:
        case ShogiPieceType.silver:
          return GameEngine.isGoldLikeMove(dr: dr, dc: dc, forward: forward);
        case ShogiPieceType.bishop:
          final bishopMove = dr.abs() == dc.abs() &&
              GameEngine.isPathClear(boardState: boardState, from: from, to: to);
          final kingOrthMove = dr.abs() + dc.abs() == 1;
          return bishopMove || kingOrthMove;
        case ShogiPieceType.rook:
          final rookMove = (dr == 0 || dc == 0) &&
              GameEngine.isPathClear(boardState: boardState, from: from, to: to);
          final kingDiagMove = dr.abs() == 1 && dc.abs() == 1;
          return rookMove || kingDiagMove;
        case ShogiPieceType.king:
        case ShogiPieceType.gold:
          break;
      }
    }

    switch (piece.type) {
      case ShogiPieceType.king:
        return dr.abs() <= 1 && dc.abs() <= 1;
      case ShogiPieceType.gold:
        return GameEngine.isGoldLikeMove(dr: dr, dc: dc, forward: forward);
      case ShogiPieceType.silver:
        final moves = [
          (forward, -1),
          (forward, 0),
          (forward, 1),
          (-forward, -1),
          (-forward, 1),
        ];
        return moves.contains((dr, dc));
      case ShogiPieceType.knight:
        return dr == 2 * forward && dc.abs() == 1;
      case ShogiPieceType.lance:
        if (dc != 0 || dr.sign != forward.sign) {
          return false;
        }
        return GameEngine.isPathClear(boardState: boardState, from: from, to: to);
      case ShogiPieceType.bishop:
        if (dr.abs() != dc.abs()) {
          return false;
        }
        return GameEngine.isPathClear(boardState: boardState, from: from, to: to);
      case ShogiPieceType.rook:
        if (dr != 0 && dc != 0) {
          return false;
        }
        return GameEngine.isPathClear(boardState: boardState, from: from, to: to);
      case ShogiPieceType.pawn:
        return dr == forward && dc == 0;
    }
  }

  ({bool canPromote, bool mustPromote}) _promotionState({
    required ShogiPiece piece,
    required BoardSquare from,
    required BoardSquare to,
  }) {
    if (!piece.type.canPromote || piece.isPromoted) {
      return (canPromote: false, mustPromote: false);
    }

    final inPromotionZoneFrom = GameEngine.isPromotionZone(row: from.row, owner: piece.owner);
    final inPromotionZoneTo = GameEngine.isPromotionZone(row: to.row, owner: piece.owner);
    final canPromote = inPromotionZoneFrom || inPromotionZoneTo;

    final mustPromote = switch (piece.type) {
      ShogiPieceType.pawn || ShogiPieceType.lance =>
        GameEngine.isDeadEndRow(to.row, piece.owner),
      ShogiPieceType.knight => GameEngine.isDeadEndKnightRow(to.row, piece.owner),
      _ => false,
    };

    return (canPromote: canPromote, mustPromote: mustPromote);
  }

  List<BoardSquare> _legalDropTargets({
    required ShogiPieceType type,
    required ShogiPlayer owner,
  }) {
    final targets = <BoardSquare>[];
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (state.board[row][col] != null) {
          continue;
        }

        final to = BoardSquare(row: row, col: col);
        if (_isLegalDropTarget(type: type, to: to, owner: owner)) {
          targets.add(to);
        }
      }
    }
    return targets;
  }

  bool _isLegalMove({
    required BoardSquare from,
    required BoardSquare to,
  }) {
    if (!_canMovePiece(boardState: state.board, from: from, to: to)) {
      return false;
    }

    final piece = state.board[from.row][from.col];
    if (piece == null) {
      return false;
    }

    final promotion = _promotionState(piece: piece, from: from, to: to);
    if (promotion.mustPromote) {
      return _isLegalAfterMove(from: from, to: to, owner: piece.owner, promote: true);
    }
    if (promotion.canPromote) {
      return _isLegalAfterMove(from: from, to: to, owner: piece.owner, promote: false) ||
          _isLegalAfterMove(from: from, to: to, owner: piece.owner, promote: true);
    }
    return _isLegalAfterMove(from: from, to: to, owner: piece.owner, promote: false);
  }

  bool _isLegalAfterMove({
    required BoardSquare from,
    required BoardSquare to,
    required ShogiPlayer owner,
    required bool promote,
  }) {
    final nextBoard = _boardByApplyingMove(
      boardState: state.board,
      from: from,
      to: to,
      promote: promote,
    );
    if (nextBoard == null) {
      return false;
    }
    return !_isInCheck(player: owner, boardState: nextBoard);
  }

  List<BoardSquare> _pseudoLegalTargets({
    required ShogiPiece piece,
    required BoardSquare from,
    required List<List<ShogiPiece?>> boardState,
  }) {
    final targets = <BoardSquare>[];

    void addStep(int dr, int dc) {
      final nr = from.row + dr;
      final nc = from.col + dc;
      if (!GameEngine.isInside(nr, nc)) {
        return;
      }
      final dest = boardState[nr][nc];
      if (dest != null && dest.owner == piece.owner) {
        return;
      }
      targets.add(BoardSquare(row: nr, col: nc));
    }

    void addRay(int dr, int dc) {
      var nr = from.row + dr;
      var nc = from.col + dc;
      while (GameEngine.isInside(nr, nc)) {
        final dest = boardState[nr][nc];
        if (dest != null) {
          if (dest.owner != piece.owner) {
            targets.add(BoardSquare(row: nr, col: nc));
          }
          return;
        }
        targets.add(BoardSquare(row: nr, col: nc));
        nr += dr;
        nc += dc;
      }
    }

    final forward = piece.owner.forward;
    if (piece.isPromoted) {
      switch (piece.type) {
        case ShogiPieceType.pawn:
        case ShogiPieceType.lance:
        case ShogiPieceType.knight:
        case ShogiPieceType.silver:
          addStep(forward, -1);
          addStep(forward, 0);
          addStep(forward, 1);
          addStep(0, -1);
          addStep(0, 1);
          addStep(-forward, 0);
          return targets;
        case ShogiPieceType.bishop:
          addRay(1, 1);
          addRay(1, -1);
          addRay(-1, 1);
          addRay(-1, -1);
          addStep(1, 0);
          addStep(-1, 0);
          addStep(0, 1);
          addStep(0, -1);
          return targets;
        case ShogiPieceType.rook:
          addRay(1, 0);
          addRay(-1, 0);
          addRay(0, 1);
          addRay(0, -1);
          addStep(1, 1);
          addStep(1, -1);
          addStep(-1, 1);
          addStep(-1, -1);
          return targets;
        case ShogiPieceType.king:
        case ShogiPieceType.gold:
          break;
      }
    }

    switch (piece.type) {
      case ShogiPieceType.king:
        addStep(1, 1);
        addStep(1, 0);
        addStep(1, -1);
        addStep(0, 1);
        addStep(0, -1);
        addStep(-1, 1);
        addStep(-1, 0);
        addStep(-1, -1);
      case ShogiPieceType.gold:
        addStep(forward, -1);
        addStep(forward, 0);
        addStep(forward, 1);
        addStep(0, -1);
        addStep(0, 1);
        addStep(-forward, 0);
      case ShogiPieceType.silver:
        addStep(forward, -1);
        addStep(forward, 0);
        addStep(forward, 1);
        addStep(-forward, -1);
        addStep(-forward, 1);
      case ShogiPieceType.knight:
        addStep(2 * forward, -1);
        addStep(2 * forward, 1);
      case ShogiPieceType.lance:
        addRay(forward, 0);
      case ShogiPieceType.bishop:
        addRay(1, 1);
        addRay(1, -1);
        addRay(-1, 1);
        addRay(-1, -1);
      case ShogiPieceType.rook:
        addRay(1, 0);
        addRay(-1, 0);
        addRay(0, 1);
        addRay(0, -1);
      case ShogiPieceType.pawn:
        addStep(forward, 0);
    }

    return targets;
  }

  bool _isLegalDrop({
    required ShogiPieceType type,
    required BoardSquare to,
    required ShogiPlayer owner,
    List<List<ShogiPiece?>>? boardState,
  }) {
    final currentBoard = boardState ?? state.board;
    switch (type) {
      case ShogiPieceType.pawn:
        if (GameEngine.isDeadEndRow(to.row, owner)) {
          return false;
        }
        for (var row = 0; row < 9; row++) {
          final piece = currentBoard[row][to.col];
          if (piece != null && piece.owner == owner && piece.type == ShogiPieceType.pawn && !piece.isPromoted) {
            return false;
          }
        }
        return true;
      case ShogiPieceType.lance:
        return !GameEngine.isDeadEndRow(to.row, owner);
      case ShogiPieceType.knight:
        return !GameEngine.isDeadEndKnightRow(to.row, owner);
      case ShogiPieceType.king:
      case ShogiPieceType.gold:
      case ShogiPieceType.silver:
      case ShogiPieceType.bishop:
      case ShogiPieceType.rook:
        return true;
    }
  }

  bool _isLegalDropTarget({
    required ShogiPieceType type,
    required BoardSquare to,
    required ShogiPlayer owner,
  }) {
    if (!_isLegalDrop(type: type, to: to, owner: owner)) {
      return false;
    }
    final nextBoard = _boardByApplyingDrop(
      boardState: state.board,
      type: type,
      to: to,
      owner: owner,
    );
    if (nextBoard == null) {
      return false;
    }
    if (_isInCheck(player: owner, boardState: nextBoard)) {
      return false;
    }
    if (_isIllegalPawnDropMate(type: type, owner: owner, boardAfterDrop: nextBoard)) {
      return false;
    }
    return true;
  }

  bool _isIllegalPawnDropMate({
    required ShogiPieceType type,
    required ShogiPlayer owner,
    required List<List<ShogiPiece?>> boardAfterDrop,
  }) {
    if (type != ShogiPieceType.pawn) {
      return false;
    }
    final defender = owner.opposite;
    if (!_isInCheck(player: defender, boardState: boardAfterDrop)) {
      return false;
    }
    return _isCheckmate(
      player: defender,
      boardState: boardAfterDrop,
      senteHandState: state.senteHand,
      goteHandState: state.goteHand,
    );
  }

  void _handleDrop({
    required ShogiPieceType type,
    required BoardSquare to,
  }) {
    if (state.board[to.row][to.col] != null) {
      state = state.copyWith(statusMessage: '駒があるマスには打てません');
      return;
    }

    final currentHand = _handForPlayer(state.turn);
    if ((currentHand[type] ?? 0) <= 0) {
      state = state.copyWith(
        clearSelectedDropType: true,
        statusMessage: 'その駒は持っていません',
      );
      return;
    }

    if (!_isLegalDrop(type: type, to: to, owner: state.turn)) {
      state = state.copyWith(statusMessage: 'その場所には打てません');
      return;
    }

    final board = _boardByApplyingDrop(
      boardState: state.board,
      type: type,
      to: to,
      owner: state.turn,
    );
    if (board == null) {
      state = state.copyWith(statusMessage: 'その場所には打てません');
      return;
    }

    if (_isInCheck(player: state.turn, boardState: board)) {
      state = state.copyWith(statusMessage: '王手を受ける形になるため、その場所には打てません');
      return;
    }

    if (_isIllegalPawnDropMate(type: type, owner: state.turn, boardAfterDrop: board)) {
      state = state.copyWith(statusMessage: '打ち歩詰めはできません');
      return;
    }

    final senteHand = Map<ShogiPieceType, int>.from(state.senteHand);
    final goteHand = Map<ShogiPieceType, int>.from(state.goteHand);
    final mover = state.turn;
    final moveRecords = [...state.moveRecords, GameEngine.formatDropRecord(player: mover, type: type, to: to)];

    _useFromHand(owner: mover, type: type, senteHand: senteHand, goteHand: goteHand);

    final nextTurn = mover.opposite;
    final registration = GameEngine.registerPositionAndDetectSennichite(
      counts: state.positionCounts,
      boardState: board,
      senteHandState: senteHand,
      goteHandState: goteHand,
      sideToMove: nextTurn,
    );

    final nextSnapshot = _makeSnapshot(
      board: board,
      senteHand: senteHand,
      goteHand: goteHand,
      turn: nextTurn,
      positionCounts: registration.counts,
      moveRecords: moveRecords,
      winner: _winnerAfterAction(
        mover: mover,
        nextTurn: nextTurn,
        boardState: board,
        senteHandState: senteHand,
        goteHandState: goteHand,
      ),
      winReason: _winnerAfterAction(
                mover: mover,
                nextTurn: nextTurn,
                boardState: board,
                senteHandState: senteHand,
                goteHandState: goteHand,
              ) !=
              null
          ? '詰み'
          : '',
      isSennichite: registration.isSennichite,
    );

    final winner = _winnerAfterAction(
      mover: mover,
      nextTurn: nextTurn,
      boardState: board,
      senteHandState: senteHand,
      goteHandState: goteHand,
    );
    final showGameEndPopup = winner != null || registration.isSennichite;

    state = state.copyWith(
      board: board,
      senteHand: senteHand,
      goteHand: goteHand,
      clearSelected: true,
      clearSelectedDropType: true,
      boardMotionTick: state.boardMotionTick + 1,
      turn: nextTurn,
        winner: winner,
        clearWinner: winner == null,
        winReason: winner != null ? '詰み' : '',
      positionCounts: registration.counts,
      moveRecords: moveRecords,
      moveHistory: [...state.moveHistory, nextSnapshot],
      isSennichite: registration.isSennichite,
        showGameEndPopup: showGameEndPopup,
      statusMessage: registration.isSennichite
          ? '千日手（同一局面4回）で引き分けです'
          : winner != null
            ? '王手詰み。${mover.label}の勝ちです'
          : '駒を打ちました。${nextTurn.label}の手番です',
    );
  }

  void _executeMove({
    required BoardSquare from,
    required BoardSquare to,
    required bool promote,
  }) {
    final movingPiece = state.board[from.row][from.col];
    if (movingPiece == null) {
      return;
    }

    final board = _boardByApplyingMove(
      boardState: state.board,
      from: from,
      to: to,
      promote: promote,
    );
    if (board == null) {
      return;
    }
    final capturedPiece = state.board[to.row][to.col];
    final senteHand = Map<ShogiPieceType, int>.from(state.senteHand);
    final goteHand = Map<ShogiPieceType, int>.from(state.goteHand);

    if (capturedPiece != null) {
      _addToHand(owner: movingPiece.owner, type: capturedPiece.type, senteHand: senteHand, goteHand: goteHand);
    }

    final mover = movingPiece.owner;
    final nextTurn = mover.opposite;
    final capturedKing = capturedPiece?.type == ShogiPieceType.king;
    final moveRecords = [
      ...state.moveRecords,
      GameEngine.formatMoveRecord(
        player: mover,
        piece: movingPiece,
        from: from,
        to: to,
        captured: capturedPiece,
        promote: promote,
      ),
    ];
    final registration = GameEngine.registerPositionAndDetectSennichite(
      counts: state.positionCounts,
      boardState: board,
      senteHandState: senteHand,
      goteHandState: goteHand,
      sideToMove: nextTurn,
    );
    final winner = capturedKing
        ? mover
        : _winnerAfterAction(
            mover: mover,
            nextTurn: nextTurn,
            boardState: board,
            senteHandState: senteHand,
            goteHandState: goteHand,
          );
    final winReason = capturedKing
        ? '王取り'
        : winner != null
            ? '詰み'
            : '';
    final showGameEndPopup = winner != null || registration.isSennichite;

    final nextSnapshot = _makeSnapshot(
      board: board,
      senteHand: senteHand,
      goteHand: goteHand,
      turn: nextTurn,
      positionCounts: registration.counts,
      moveRecords: moveRecords,
      winner: winner,
      winReason: winReason,
      isSennichite: registration.isSennichite,
    );

    state = state.copyWith(
      board: board,
      senteHand: senteHand,
      goteHand: goteHand,
      clearSelected: true,
      clearSelectedDropType: true,
      clearPendingPromotionMove: true,
      boardMotionTick: state.boardMotionTick + 1,
      turn: nextTurn,
      winner: winner,
      clearWinner: winner == null,
      winReason: winReason,
      positionCounts: registration.counts,
      moveRecords: moveRecords,
      moveHistory: [...state.moveHistory, nextSnapshot],
      isSennichite: registration.isSennichite,
      showGameEndPopup: showGameEndPopup,
      statusMessage: registration.isSennichite
          ? '千日手（同一局面4回）で引き分けです'
          : capturedKing
            ? '王を取りました。${mover.label}の勝ちです'
          : winner != null
              ? '王手詰み。${mover.label}の勝ちです'
          : '移動しました。${nextTurn.label}の手番です',
    );
  }

  List<List<ShogiPiece?>>? _boardByApplyingMove({
    required List<List<ShogiPiece?>> boardState,
    required BoardSquare from,
    required BoardSquare to,
    required bool promote,
  }) {
    final movingPiece = boardState[from.row][from.col];
    if (movingPiece == null) {
      return null;
    }
    final next = _cloneBoard(boardState);
    next[from.row][from.col] = null;
    next[to.row][to.col] = promote && movingPiece.type.canPromote
        ? movingPiece.copyWith(isPromoted: true)
        : movingPiece;
    return next;
  }

  List<List<ShogiPiece?>>? _boardByApplyingDrop({
    required List<List<ShogiPiece?>> boardState,
    required ShogiPieceType type,
    required BoardSquare to,
    required ShogiPlayer owner,
  }) {
    if (boardState[to.row][to.col] != null) {
      return null;
    }
    final next = _cloneBoard(boardState);
    next[to.row][to.col] = ShogiPiece(owner: owner, type: type);
    return next;
  }

  bool _isInCheck({
    required ShogiPlayer player,
    required List<List<ShogiPiece?>> boardState,
  }) {
    final kingSquare = _findKingSquare(player: player, boardState: boardState);
    if (kingSquare == null) {
      return true;
    }
    return _isSquareAttacked(square: kingSquare, attacker: player.opposite, boardState: boardState);
  }

  BoardSquare? _findKingSquare({
    required ShogiPlayer player,
    required List<List<ShogiPiece?>> boardState,
  }) {
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        final piece = boardState[row][col];
        if (piece != null && piece.owner == player && piece.type == ShogiPieceType.king) {
          return BoardSquare(row: row, col: col);
        }
      }
    }
    return null;
  }

  bool _isSquareAttacked({
    required BoardSquare square,
    required ShogiPlayer attacker,
    required List<List<ShogiPiece?>> boardState,
  }) {
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        final piece = boardState[row][col];
        if (piece != null && piece.owner == attacker) {
          if (_canMovePiece(boardState: boardState, from: BoardSquare(row: row, col: col), to: square)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool _isCheckmate({
    required ShogiPlayer player,
    required List<List<ShogiPiece?>> boardState,
    required Map<ShogiPieceType, int> senteHandState,
    required Map<ShogiPieceType, int> goteHandState,
  }) {
    if (!_isInCheck(player: player, boardState: boardState)) {
      return false;
    }
    return !_hasAnyLegalEscape(
      player: player,
      boardState: boardState,
      senteHandState: senteHandState,
      goteHandState: goteHandState,
    );
  }

  bool _hasAnyLegalEscape({
    required ShogiPlayer player,
    required List<List<ShogiPiece?>> boardState,
    required Map<ShogiPieceType, int> senteHandState,
    required Map<ShogiPieceType, int> goteHandState,
  }) {
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        final piece = boardState[row][col];
        if (piece == null || piece.owner != player) {
          continue;
        }
        final from = BoardSquare(row: row, col: col);
        final targets = _pseudoLegalTargets(piece: piece, from: from, boardState: boardState);
        for (final to in targets) {
          if (!_canMovePiece(boardState: boardState, from: from, to: to)) {
            continue;
          }
          final promotion = _promotionState(piece: piece, from: from, to: to);
          if (promotion.mustPromote) {
            final next = _boardByApplyingMove(boardState: boardState, from: from, to: to, promote: true);
            if (next != null && !_isInCheck(player: player, boardState: next)) {
              return true;
            }
          } else if (promotion.canPromote) {
            final nextWithout = _boardByApplyingMove(boardState: boardState, from: from, to: to, promote: false);
            if (nextWithout != null && !_isInCheck(player: player, boardState: nextWithout)) {
              return true;
            }
            final nextWith = _boardByApplyingMove(boardState: boardState, from: from, to: to, promote: true);
            if (nextWith != null && !_isInCheck(player: player, boardState: nextWith)) {
              return true;
            }
          } else {
            final next = _boardByApplyingMove(boardState: boardState, from: from, to: to, promote: false);
            if (next != null && !_isInCheck(player: player, boardState: next)) {
              return true;
            }
          }
        }
      }
    }

    final hand = player == ShogiPlayer.sente ? senteHandState : goteHandState;
    for (final type in ShogiPieceType.handOrder) {
      if ((hand[type] ?? 0) <= 0) {
        continue;
      }
      for (var row = 0; row < 9; row++) {
        for (var col = 0; col < 9; col++) {
          if (boardState[row][col] != null) {
            continue;
          }
          final to = BoardSquare(row: row, col: col);
          if (!_isLegalDrop(type: type, to: to, owner: player, boardState: boardState)) {
            continue;
          }
          final next = _boardByApplyingDrop(boardState: boardState, type: type, to: to, owner: player);
          if (next != null && !_isInCheck(player: player, boardState: next)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  ShogiPlayer? _winnerAfterAction({
    required ShogiPlayer mover,
    required ShogiPlayer nextTurn,
    required List<List<ShogiPiece?>> boardState,
    required Map<ShogiPieceType, int> senteHandState,
    required Map<ShogiPieceType, int> goteHandState,
  }) {
    if (_isInCheck(player: nextTurn, boardState: boardState) &&
        _isCheckmate(
          player: nextTurn,
          boardState: boardState,
          senteHandState: senteHandState,
          goteHandState: goteHandState,
        )) {
      return mover;
    }
    return null;
  }

  ShogiGameSnapshot _makeSnapshot({
    required List<List<ShogiPiece?>> board,
    required Map<ShogiPieceType, int> senteHand,
    required Map<ShogiPieceType, int> goteHand,
    required ShogiPlayer turn,
    required Map<String, int> positionCounts,
    required List<String> moveRecords,
    ShogiPlayer? winner,
    String winReason = '',
    bool isSennichite = false,
  }) {
    return ShogiGameSnapshot(
      board: _cloneBoard(board),
      selected: null,
      selectedDropType: null,
      senteHand: Map<ShogiPieceType, int>.from(senteHand),
      goteHand: Map<ShogiPieceType, int>.from(goteHand),
      pendingPromotionMove: null,
      turn: turn,
      winner: winner,
      winReason: winReason,
      isSennichite: isSennichite,
      isInterrupted: false,
      positionCounts: Map<String, int>.from(positionCounts),
      moveRecords: List<String>.from(moveRecords),
    );
  }

  void _addToHand({
    required ShogiPlayer owner,
    required ShogiPieceType type,
    required Map<ShogiPieceType, int> senteHand,
    required Map<ShogiPieceType, int> goteHand,
  }) {
    final target = owner == ShogiPlayer.sente ? senteHand : goteHand;
    target[type] = (target[type] ?? 0) + 1;
  }

  void _useFromHand({
    required ShogiPlayer owner,
    required ShogiPieceType type,
    required Map<ShogiPieceType, int> senteHand,
    required Map<ShogiPieceType, int> goteHand,
  }) {
    final target = owner == ShogiPlayer.sente ? senteHand : goteHand;
    final nextValue = (target[type] ?? 0) - 1;
    if (nextValue <= 0) {
      target.remove(type);
    } else {
      target[type] = nextValue;
    }
  }
}