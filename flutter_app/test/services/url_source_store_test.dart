import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/url_source_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('adds, normalizes, loads, and removes registered URLs', () async {
    final tempDir = await Directory.systemTemp.createTemp('url-source-store-test');
    addTearDown(() => tempDir.delete(recursive: true));
    final store = URLSourceStore();

    final added = await store.add('shogiwars.heroz.jp/games/123');
    final loaded = await store.load();

    expect(added, URLSourceAddResult.added);
    expect(loaded, hasLength(1));
    expect(loaded.single.urlString, 'https://shogiwars.heroz.jp/games/123');

    await store.remove(loaded.single.id);

    expect(await store.load(), isEmpty);
  });

  test('rejects duplicate and malformed urls', () async {
    final tempDir = await Directory.systemTemp.createTemp('url-source-store-dupe-test');
    addTearDown(() => tempDir.delete(recursive: true));
    final store = URLSourceStore();

    expect(await store.add(''), URLSourceAddResult.empty);
    expect(await store.add('not a url'), URLSourceAddResult.invalidFormat);
    expect(await store.add('https://81dojo.com/test'), URLSourceAddResult.added);
    expect(await store.add('81dojo.com/test'), URLSourceAddResult.duplicate);
  });
}