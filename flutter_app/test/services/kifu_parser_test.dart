import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/models/shogi_models.dart';
import 'package:flutter_app/services/kifu_parser.dart';

void main() {
  test('parses basic KIF fixture and preserves final result', () {
    final text = File('test/fixtures/basic_game.kif').readAsStringSync();
    final result = KifuParser.parse(text: text, includeHistory: true);

    expect(result.playerSente, '先手太郎');
    expect(result.playerGote, '後手花子');
    expect(result.record.snapshot.winner, ShogiPlayer.gote);
    expect(result.record.snapshot.moveRecords.length, 2);
    expect(result.record.moveHistory?.length, 2);
    expect(result.record.snapshot.board[5][2]?.type, ShogiPieceType.pawn);
    expect(result.record.snapshot.board[3][6]?.owner, ShogiPlayer.gote);
  });
}