import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app/providers.dart';
import 'package:flutter_app/domain/models/shogi_models.dart';

void main() {
  test('selecting a pawn then tapping forward moves it and advances turn', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(gameSessionProvider.notifier);
    controller.resetSession();

    controller.handleBoardTap(const BoardSquare(row: 6, col: 4));
    expect(container.read(gameSessionProvider).selected?.row, 6);

    controller.handleBoardTap(const BoardSquare(row: 5, col: 4));

    final state = container.read(gameSessionProvider);
    expect(state.board[6][4], isNull);
    expect(state.board[5][4]?.type, ShogiPieceType.pawn);
    expect(state.board[5][4]?.owner, ShogiPlayer.sente);
    expect(state.turn, ShogiPlayer.gote);
    expect(state.selected, isNull);
    expect(state.moveRecords, hasLength(1));
  });

  test('selecting a hand piece then tapping an empty square drops it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(gameSessionProvider.notifier);
    controller.resetSession();
    controller.updateHands(senteHand: const {ShogiPieceType.gold: 1});

    controller.toggleDropSelection(ShogiPieceType.gold);
    controller.handleBoardTap(const BoardSquare(row: 4, col: 4));

    final state = container.read(gameSessionProvider);
    expect(state.board[4][4]?.type, ShogiPieceType.gold);
    expect(state.board[4][4]?.owner, ShogiPlayer.sente);
    expect(state.senteHand.containsKey(ShogiPieceType.gold), isFalse);
    expect(state.turn, ShogiPlayer.gote);
    expect(state.selectedDropType, isNull);
    expect(state.moveRecords.single.contains('打'), isTrue);
  });

  test('optional promotion creates pending move and can be accepted', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(gameSessionProvider.notifier);
    controller.resetSession();

    controller.updateBoard([
      [
        null,
        null,
        null,
        null,
        const ShogiPiece(owner: ShogiPlayer.gote, type: ShogiPieceType.king),
        null,
        null,
        null,
        null,
      ],
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      [
        null,
        null,
        null,
        null,
        const ShogiPiece(owner: ShogiPlayer.sente, type: ShogiPieceType.bishop),
        null,
        null,
        null,
        null,
      ],
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      [
        null,
        null,
        null,
        null,
        const ShogiPiece(owner: ShogiPlayer.sente, type: ShogiPieceType.king),
        null,
        null,
        null,
        null,
      ],
    ]);

    controller.handleBoardTap(const BoardSquare(row: 4, col: 4));
    controller.handleBoardTap(const BoardSquare(row: 2, col: 2));

    var state = container.read(gameSessionProvider);

    expect(state.pendingPromotionMove, isNotNull);

    controller.resolvePendingPromotion(promote: true);

    state = container.read(gameSessionProvider);
    expect(state.pendingPromotionMove, isNull);
    expect(state.board[2][2]?.isPromoted, isTrue);
    expect(state.turn, ShogiPlayer.gote);
  });

  test('capturing king marks winner and shows game end popup', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(gameSessionProvider.notifier);
    controller.resetSession();

    controller.updateBoard([
      [null, null, null, null, const ShogiPiece(owner: ShogiPlayer.gote, type: ShogiPieceType.king), null, null, null, null],
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      [null, null, null, null, const ShogiPiece(owner: ShogiPlayer.sente, type: ShogiPieceType.rook), null, null, null, null],
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      [const ShogiPiece(owner: ShogiPlayer.sente, type: ShogiPieceType.king), null, null, null, null, null, null, null, null],
    ]);

    controller.handleBoardTap(const BoardSquare(row: 5, col: 4));
    controller.handleBoardTap(const BoardSquare(row: 0, col: 4));

    var state = container.read(gameSessionProvider);
    expect(state.pendingPromotionMove, isNotNull);

    controller.resolvePendingPromotion(promote: false);

    state = container.read(gameSessionProvider);
    expect(state.winner, ShogiPlayer.sente);
    expect(state.winReason, '王取り');
    expect(state.showGameEndPopup, isTrue);
  });

  test('pinned piece cannot move and expose own king to check', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(gameSessionProvider.notifier);
    controller.resetSession();

    controller.updateBoard([
      [
        null,
        null,
        null,
        null,
        const ShogiPiece(owner: ShogiPlayer.gote, type: ShogiPieceType.rook),
        null,
        null,
        null,
        const ShogiPiece(owner: ShogiPlayer.gote, type: ShogiPieceType.king),
      ],
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      List<ShogiPiece?>.filled(9, null),
      [
        null,
        null,
        null,
        null,
        const ShogiPiece(owner: ShogiPlayer.sente, type: ShogiPieceType.gold),
        null,
        null,
        null,
        null,
      ],
      [
        null,
        null,
        null,
        null,
        const ShogiPiece(owner: ShogiPlayer.sente, type: ShogiPieceType.king),
        null,
        null,
        null,
        null,
      ],
    ]);

    controller.handleBoardTap(const BoardSquare(row: 7, col: 4));
    final legalTargets = controller.currentLegalTargets();
    expect(
      legalTargets.any((square) => square.row == 7 && square.col == 3),
      isFalse,
    );

    controller.handleBoardTap(const BoardSquare(row: 7, col: 3));

    final state = container.read(gameSessionProvider);
    expect(state.board[7][4]?.type, ShogiPieceType.gold);
    expect(state.statusMessage, 'その場所には移動できません');
  });

  test('review mode can navigate history and resume from selected snapshot', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(gameSessionProvider.notifier);
    controller.resetSession();

    controller.handleBoardTap(const BoardSquare(row: 6, col: 4));
    controller.handleBoardTap(const BoardSquare(row: 5, col: 4));
    controller.handleBoardTap(const BoardSquare(row: 2, col: 4));
    controller.handleBoardTap(const BoardSquare(row: 3, col: 4));

    controller.enterReviewMode();

    var state = container.read(gameSessionProvider);
    expect(state.isReviewMode, isTrue);
    expect(state.reviewIndex, 2);
    expect(state.statusMessage, '検討モード: 終局局面');

    controller.goToReviewStart();
    state = container.read(gameSessionProvider);
    expect(state.reviewIndex, 0);
    expect(state.board[6][4]?.type, ShogiPieceType.pawn);
    expect(state.board[5][4], isNull);

    controller.moveReviewBy(1);
    state = container.read(gameSessionProvider);
    expect(state.reviewIndex, 1);
    expect(state.board[6][4], isNull);
    expect(state.board[5][4]?.owner, ShogiPlayer.sente);
    expect(state.turn, ShogiPlayer.gote);

    controller.resumeFromReview();
    state = container.read(gameSessionProvider);
    expect(state.isReviewMode, isFalse);
    expect(state.turn, ShogiPlayer.gote);
    expect(state.moveHistory, hasLength(2));
    expect(state.moveRecords, hasLength(1));
    expect(state.statusMessage, '後手の手番です');
  });

  test('resigning current player awards win to the opponent and shows game end popup', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(gameSessionProvider.notifier);
    controller.resetSession();

    controller.resignCurrentPlayer();

    final state = container.read(gameSessionProvider);
    expect(state.winner, ShogiPlayer.gote);
    expect(state.winReason, '投了');
    expect(state.showGameEndPopup, isTrue);
    expect(state.statusMessage, '先手が投了。後手の勝ちです');
  });
}