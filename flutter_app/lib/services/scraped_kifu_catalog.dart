import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/shogi_models.dart';
import 'shogi_extend_backend_service.dart';

// Keep the concrete storage choice behind a single factory so a future
// server-backed catalog can replace local persistence without touching UI call sites.
ScrapedKifuCatalog createDefaultScrapedKifuCatalog() => LocalScrapedKifuCatalog();

abstract class ScrapedKifuCatalog {
  // The UI reads scraped results from this catalog. The backend currently acts
  // only as a scrape executor and detail source, while persisted ownership stays local.
  Future<List<ScrapedKifuRecord>> listByUsernames(Iterable<String> usernames, {int limitPerUser = 5});

  Future<ScrapedKifuRecord?> get(String username, String itemId);

  Future<void> upsertAll(Iterable<ScrapedKifuRecord> records);

  Future<void> removeByUsername(String username);
}

class LocalScrapedKifuCatalog implements ScrapedKifuCatalog {
  static const _storageKey = 'local_scraped_kifu_catalog_v1';

  @override
  Future<List<ScrapedKifuRecord>> listByUsernames(Iterable<String> usernames, {int limitPerUser = 5}) async {
    final wanted = usernames.map((username) => username.trim().toLowerCase()).toSet();
    final records = await _loadAll();
    final filtered = records.where((record) => wanted.contains(record.username.trim().toLowerCase())).toList();

    final result = <ScrapedKifuRecord>[];
    for (final username in usernames) {
      final perUser = filtered.where((record) => record.username == username).toList()
        ..sort((left, right) => right.scrapedAt.compareTo(left.scrapedAt));
      result.addAll(perUser.take(limitPerUser));
    }
    return result;
  }

  @override
  Future<ScrapedKifuRecord?> get(String username, String itemId) async {
    final records = await _loadAll();
    for (final record in records) {
      if (record.username == username && record.id == itemId) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> upsertAll(Iterable<ScrapedKifuRecord> records) async {
    final current = await _loadAll();
    final byKey = <String, ScrapedKifuRecord>{
      for (final record in current) _keyFor(record.username, record.id): record,
    };
    for (final record in records) {
      byKey[_keyFor(record.username, record.id)] = record.copyWith(storedAt: DateTime.now());
    }
    final next = byKey.values.toList()
      ..sort((left, right) => right.scrapedAt.compareTo(left.scrapedAt));
    await _saveAll(next);
  }

  @override
  Future<void> removeByUsername(String username) async {
    final current = await _loadAll();
    final next = current.where((record) => record.username != username).toList(growable: false);
    await _saveAll(next);
  }

  Future<List<ScrapedKifuRecord>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? '[]';
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => ScrapedKifuRecord.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> _saveAll(List<ScrapedKifuRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(records.map((record) => record.toJson()).toList(growable: false)),
    );
  }

  String _keyFor(String username, String itemId) => '${username.toLowerCase()}::$itemId';
}

ScrapedKifuRecord scrapedRecordFromBackendDetail(BackendKifuItemDetailResponse detail) {
  return ScrapedKifuRecord(
    id: detail.id,
    username: detail.username,
    jobId: detail.jobId,
    sourceGameId: detail.sourceGameId,
    sourceGameUrl: detail.sourceGameUrl,
    searchedPage: detail.searchedPage,
    scrapedAt: detail.scrapedAt,
    matchDateTime: detail.matchDateTime,
    players: detail.players,
    result: detail.result,
    kifText: detail.kifText,
    metadata: detail.metadata,
  );
}
