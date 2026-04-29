import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/shogi_models.dart';

enum URLSourceAddResult {
  added,
  duplicate,
  invalidFormat,
  unsupportedProvider,
  empty;

  bool get isSuccess => this == URLSourceAddResult.added;
}

class URLSourceStore {
  static const _storageKey = 'registered_kifu_source_urls_v1';

  Future<List<RegisteredKifuSource>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? '[]';
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => RegisteredKifuSource.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<URLSourceAddResult> add(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return URLSourceAddResult.empty;
    }
    final normalized = normalizedURLString(trimmed);
    if (normalized == null) {
      return URLSourceAddResult.invalidFormat;
    }

    final current = (await load()).toList();
    if (current.any((entry) => entry.urlString.toLowerCase() == normalized.toLowerCase())) {
      return URLSourceAddResult.duplicate;
    }

    current.insert(
      0,
      RegisteredKifuSource(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        urlString: normalized,
        createdAt: DateTime.now(),
      ),
    );
    await _save(current);
    return URLSourceAddResult.added;
  }

  Future<void> remove(String id) async {
    final current = (await load()).where((entry) => entry.id != id).toList(growable: false);
    await _save(current);
  }

  String? normalizedURLString(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final candidate = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(candidate);
    if (uri == null) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }
    if (uri.host.isEmpty || uri.host.contains(RegExp(r'\s')) || !uri.host.contains('.')) {
      return null;
    }
    return uri.replace(scheme: scheme).toString();
  }

  Future<void> _save(List<RegisteredKifuSource> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((entry) => entry.toJson()).toList(growable: false)),
    );
  }
}