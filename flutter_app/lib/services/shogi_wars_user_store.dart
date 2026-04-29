import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/shogi_models.dart';

enum ShogiWarsUserAddResult {
  added,
  duplicate,
  invalidUsername,
  backendUnavailable,
  empty;

  bool get isSuccess => this == ShogiWarsUserAddResult.added;
}

class ShogiWarsUserStore {
  static const _storageKey = 'registered_shogi_wars_users_v1';

  Future<List<RegisteredShogiWarsUser>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? '[]';
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => RegisteredShogiWarsUser.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ShogiWarsUserAddResult?> validationResult(String rawUsername) async {
    final trimmed = rawUsername.trim();
    if (trimmed.isEmpty) {
      return ShogiWarsUserAddResult.empty;
    }
    final normalized = normalizeUsername(trimmed);
    if (normalized == null) {
      return ShogiWarsUserAddResult.invalidUsername;
    }
    final current = await load();
    if (current.any((entry) => entry.normalizedUsername == normalized.toLowerCase())) {
      return ShogiWarsUserAddResult.duplicate;
    }
    return null;
  }

  Future<ShogiWarsUserAddResult> add(String rawUsername) async {
    final validation = await validationResult(rawUsername);
    if (validation != null) {
      return validation;
    }

    final normalized = normalizeUsername(rawUsername.trim())!;
    final current = (await load()).toList();
    current.insert(
      0,
      RegisteredShogiWarsUser(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        username: normalized,
        createdAt: DateTime.now(),
      ),
    );
    await _save(current);
    return ShogiWarsUserAddResult.added;
  }

  Future<void> remove(String id) async {
    final current = (await load()).where((entry) => entry.id != id).toList(growable: false);
    await _save(current);
  }

  String? normalizeUsername(String rawUsername) {
    final trimmed = rawUsername.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final valid = RegExp(r'^[A-Za-z0-9_-]+$');
    if (!valid.hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }

  Future<void> _save(List<RegisteredShogiWarsUser> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((entry) => entry.toJson()).toList(growable: false)),
    );
  }
}
