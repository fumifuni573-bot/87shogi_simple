import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/models/shogi_models.dart';

void main() {
  test('player helpers match Swift behavior', () {
    expect(ShogiPlayer.sente.label, '先手');
    expect(ShogiPlayer.sente.forward, -1);
    expect(ShogiPlayer.sente.opposite, ShogiPlayer.gote);
  });

  test('piece symbol changes when promoted', () {
    const piece = ShogiPiece(
      owner: ShogiPlayer.sente,
      type: ShogiPieceType.pawn,
      isPromoted: true,
    );
    expect(piece.displaySymbol, 'と');
  });

  test('snapshot serializes and restores enum keyed hands', () {
    final snapshot = ShogiGameSnapshot(
      board: List.generate(9, (_) => List<ShogiPiece?>.filled(9, null)),
      selected: const BoardSquare(row: 0, col: 0),
      selectedDropType: ShogiPieceType.rook,
      senteHand: const {ShogiPieceType.rook: 1},
      goteHand: const {ShogiPieceType.pawn: 2},
      pendingPromotionMove: const PromotionPendingMove(
        from: BoardSquare(row: 6, col: 6),
        to: BoardSquare(row: 5, col: 6),
      ),
      turn: ShogiPlayer.gote,
      winner: null,
      winReason: '',
      isSennichite: false,
      isInterrupted: false,
      positionCounts: const {'abc': 1},
      moveRecords: const ['先手 ７七 歩 → ７六'],
    );

    final restored = ShogiGameSnapshot.fromJson(snapshot.toJson());
    expect(restored.turn, ShogiPlayer.gote);
    expect(restored.senteHand[ShogiPieceType.rook], 1);
    expect(restored.pendingPromotionMove?.from.row, 6);
  });
}