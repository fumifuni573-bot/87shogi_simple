import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/models/shogi_models.dart';
import 'package:flutter_app/services/scraped_kifu_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('upsertAll stores and filters scraped records locally by username', () async {
    final catalog = LocalScrapedKifuCatalog();
    await catalog.upsertAll(<ScrapedKifuRecord>[
      ScrapedKifuRecord(
        id: 'item-1',
        username: 'chubby_cat',
        sourceGameId: 'game-1',
        sourceGameUrl: 'https://example.com/game-1',
        searchedPage: 1,
        scrapedAt: DateTime(2026, 4, 30, 10, 0),
        players: const <String, String?>{'sente': 'chubby_cat', 'gote': 'mikyun'},
        result: '先手勝ち',
        kifText: '開始日時：2026/04/30 10:00:00\n手数----指手---------\n1 ７六歩(77)',
      ),
      ScrapedKifuRecord(
        id: 'item-2',
        username: 'other_user',
        sourceGameId: 'game-2',
        sourceGameUrl: 'https://example.com/game-2',
        searchedPage: 1,
        scrapedAt: DateTime(2026, 4, 30, 9, 0),
        players: const <String, String?>{'sente': 'other_user', 'gote': 'mikyun'},
        result: '後手勝ち',
        kifText: '開始日時：2026/04/30 09:00:00\n手数----指手---------\n1 ２六歩(27)',
      ),
    ]);

    final entries = await catalog.listByUsernames(const <String>['chubby_cat']);
    final stored = await catalog.get('chubby_cat', 'item-1');

    expect(entries, hasLength(1));
    expect(entries.single.id, 'item-1');
    expect(stored?.kifText, contains('1 ７六歩(77)'));
  });

  test('removeByUsername deletes only the selected local scraped records', () async {
    final catalog = LocalScrapedKifuCatalog();
    await catalog.upsertAll(<ScrapedKifuRecord>[
      ScrapedKifuRecord(
        id: 'item-1',
        username: 'chubby_cat',
        sourceGameId: 'game-1',
        sourceGameUrl: 'https://example.com/game-1',
        searchedPage: 1,
        scrapedAt: DateTime(2026, 4, 30, 10, 0),
        players: const <String, String?>{'sente': 'chubby_cat', 'gote': 'mikyun'},
        result: '先手勝ち',
        kifText: '開始日時：2026/04/30 10:00:00\n手数----指手---------\n1 ７六歩(77)',
      ),
      ScrapedKifuRecord(
        id: 'item-2',
        username: 'other_user',
        sourceGameId: 'game-2',
        sourceGameUrl: 'https://example.com/game-2',
        searchedPage: 1,
        scrapedAt: DateTime(2026, 4, 30, 9, 0),
        players: const <String, String?>{'sente': 'other_user', 'gote': 'mikyun'},
        result: '後手勝ち',
        kifText: '開始日時：2026/04/30 09:00:00\n手数----指手---------\n1 ２六歩(27)',
      ),
    ]);

    await catalog.removeByUsername('chubby_cat');

    final chubby = await catalog.listByUsernames(const <String>['chubby_cat']);
    final other = await catalog.listByUsernames(const <String>['other_user']);
    expect(chubby, isEmpty);
    expect(other, hasLength(1));
    expect(other.single.id, 'item-2');
  });
}
