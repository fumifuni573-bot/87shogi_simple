import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/models/shogi_models.dart';
import 'package:flutter_app/services/kifu_codec.dart';

void main() {
  test('encodes move records into KIF-like text', () {
    final record = PersistedShogiGameRecord(
      snapshot: const ShogiGameSnapshot(
        board: [],
        selected: null,
        selectedDropType: null,
        senteHand: {},
        goteHand: {},
        pendingPromotionMove: null,
        turn: ShogiPlayer.gote,
        winner: ShogiPlayer.sente,
        winReason: '投了',
        isSennichite: false,
        isInterrupted: false,
        positionCounts: {},
        moveRecords: ['先手 7七 歩 → 7六', '後手 3三 歩 → 3四'],
      ),
      moveHistory: null,
      savedAt: DateTime(2026, 4, 28, 9, 30, 15),
      kifExtendedData: const KifExtendedData(
        headers: {
          '先手': '先手太郎',
          '後手': '後手花子',
          '手合割': '平手',
        },
      ),
    );

    final text = KifuCodec.encode(record);

    expect(text, contains('開始日時：2026/04/28 09:30:15'));
    expect(text, contains('先手：先手太郎'));
    expect(text, contains('後手：後手花子'));
    expect(text, contains('結果：先手の勝ち（投了）'));
    expect(text, contains('1 ７六歩(77)'));
    expect(text, contains('2 ３四歩(33)'));
    expect(text, contains('3 投了'));
  });
}