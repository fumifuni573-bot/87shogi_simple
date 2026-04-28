import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/models/shogi_models.dart';
import 'package:flutter_app/logic/game_engine.dart';

void main() {
  test('initial board contains standard setup', () {
    final board = GameEngine.initialBoard();
    expect(board[8][4]?.type, ShogiPieceType.king);
    expect(board[0][4]?.owner, ShogiPlayer.gote);
    expect(board[7][7]?.type, ShogiPieceType.rook);
  });

  test('handicap removes expected pieces', () {
    final board = GameEngine.initialBoard(handicap: GameHandicap.twoPieces);
    expect(board[7][7], isNull);
    expect(board[7][1], isNull);
  });

  test('position key reflects board and hands deterministically', () {
    final board = GameEngine.initialBoard();
    final key = GameEngine.positionKey(
      boardState: board,
      senteHandState: const {ShogiPieceType.pawn: 1},
      goteHandState: const {},
      sideToMove: ShogiPlayer.sente,
    );
    expect(key.startsWith('S|'), isTrue);
    expect(key.contains('P1'), isTrue);
  });
}