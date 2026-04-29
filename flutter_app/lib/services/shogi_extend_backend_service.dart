import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class BackendSettingsStore {
  BackendSettingsStore({Future<Directory> Function()? documentsDirectoryProvider})
      : _documentsDirectoryProvider = documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  static const defaultBaseUrl = 'http://127.0.0.1:8000';
  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<File> _storageFile() async {
    final baseDir = await _documentsDirectoryProvider();
    final file = File('${baseDir.path}${Platform.pathSeparator}shogi_extend_backend_settings_v1.json');
    if (!file.existsSync()) {
      await file.writeAsString(jsonEncode(const {'baseUrl': defaultBaseUrl}), flush: true);
    }
    return file;
  }

  Future<String> loadBaseUrl() async {
    final file = await _storageFile();
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded['baseUrl'] as String? ?? defaultBaseUrl;
  }

  Future<void> saveBaseUrl(String value) async {
    final file = await _storageFile();
    await file.writeAsString(jsonEncode({'baseUrl': value}), flush: true);
  }

  String? normalizeBaseUrl(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final candidate = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final uri = Uri.tryParse(candidate);
    if (uri == null) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }
    if (uri.host.isEmpty) {
      return null;
    }
    return uri.replace(scheme: scheme).toString().replaceFirst(RegExp(r'/+$'), '');
  }
}

class ShogiExtendBackendException implements Exception {
  ShogiExtendBackendException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BackendTrackedSourceResponse {
  const BackendTrackedSourceResponse({
    required this.id,
    required this.username,
    required this.enabled,
  });

  final String id;
  final String username;
  final bool enabled;

  factory BackendTrackedSourceResponse.fromJson(Map<String, dynamic> json) {
    return BackendTrackedSourceResponse(
      id: json['id'] as String,
      username: json['username'] as String,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class BackendScrapeJobResponse {
  const BackendScrapeJobResponse({
    required this.id,
    required this.username,
    required this.mode,
    required this.status,
    this.requestedAt,
    this.startedAt,
    this.finishedAt,
    this.processedPages,
    this.insertedGames,
    this.skippedGames,
    this.fetchedGames,
    this.errorSummary,
  });

  final String id;
  final String username;
  final String mode;
  final String status;
  final DateTime? requestedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int? processedPages;
  final int? insertedGames;
  final int? skippedGames;
  final int? fetchedGames;
  final String? errorSummary;

  String get statusLabel {
    switch (status) {
      case 'queued':
        return '待機中';
      case 'running':
        return '取得中';
      case 'succeeded':
        return '完了';
      case 'failed':
        return '失敗';
      default:
        return status;
    }
  }

  String get summaryLine {
    if (status == 'failed' && errorSummary != null && errorSummary!.isNotEmpty) {
      return errorSummary!;
    }
    return '新規${insertedGames ?? 0}件 / スキップ${skippedGames ?? 0}件 / ${processedPages ?? 0}ページ';
  }

  bool get isActive => status == 'queued' || status == 'running';

  factory BackendScrapeJobResponse.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) {
      final value = json[key] as String?;
      return value == null ? null : DateTime.tryParse(value);
    }

    return BackendScrapeJobResponse(
      id: json['id'] as String,
      username: json['username'] as String,
      mode: json['mode'] as String? ?? '',
      status: json['status'] as String? ?? '',
      requestedAt: parseDate('requested_at'),
      startedAt: parseDate('started_at'),
      finishedAt: parseDate('finished_at'),
      processedPages: json['processed_pages'] as int?,
      insertedGames: json['inserted_games'] as int?,
      skippedGames: json['skipped_games'] as int?,
      fetchedGames: json['fetched_games'] as int?,
      errorSummary: json['error_summary'] as String?,
    );
  }
}

class BackendKifuItemSummaryResponse {
  const BackendKifuItemSummaryResponse({
    required this.id,
    required this.username,
    required this.sourceGameId,
    required this.sourceGameUrl,
    required this.searchedPage,
    required this.scrapedAt,
    required this.players,
    this.jobId,
    this.matchDateTime,
    this.result,
  });

  final String id;
  final String username;
  final String? jobId;
  final String sourceGameId;
  final String sourceGameUrl;
  final int searchedPage;
  final DateTime scrapedAt;
  final DateTime? matchDateTime;
  final Map<String, String?> players;
  final String? result;

  String get matchupLabel => '${players['sente'] ?? '先手不明'} vs ${players['gote'] ?? '後手不明'}';

  String get summaryLine => '${result ?? '結果不明'} / p.$searchedPage';

  factory BackendKifuItemSummaryResponse.fromJson(Map<String, dynamic> json) {
    final playersRaw = json['players'] as Map<String, dynamic>? ?? const {};
    return BackendKifuItemSummaryResponse(
      id: json['id'] as String,
      username: json['username'] as String,
      jobId: json['job_id'] as String?,
      sourceGameId: json['source_game_id'] as String? ?? '',
      sourceGameUrl: json['source_game_url'] as String? ?? '',
      searchedPage: json['searched_page'] as int? ?? 0,
      scrapedAt: DateTime.tryParse(json['scraped_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      matchDateTime: DateTime.tryParse(json['match_datetime'] as String? ?? ''),
      players: playersRaw.map((key, value) => MapEntry(key, value as String?)),
      result: json['result'] as String?,
    );
  }
}

class ShogiExtendBackendService {
  ShogiExtendBackendService({
    BackendSettingsStore? settingsStore,
    HttpClient? client,
  })  : _settingsStore = settingsStore ?? BackendSettingsStore(),
        _client = client ?? HttpClient();

  final BackendSettingsStore _settingsStore;
  final HttpClient _client;

  Future<String> get baseUrl async => _settingsStore.loadBaseUrl();

  Future<void> saveBaseUrl(String value) async {
    await _settingsStore.saveBaseUrl(value);
  }

  String? normalizeBaseUrl(String value) => _settingsStore.normalizeBaseUrl(value);

  Future<BackendTrackedSourceResponse> registerTrackedUser(String username) async {
    return _sendJsonRequest(
      '/tracked-sources',
      method: 'POST',
      body: {'username': username, 'enabled': true},
      parser: (json) => BackendTrackedSourceResponse.fromJson(json),
    );
  }

  Future<BackendScrapeJobResponse> enqueueScrapeJob(String username, {String mode = 'incremental'}) async {
    return _sendJsonRequest(
      '/scrape-jobs',
      method: 'POST',
      body: {'username': username, 'mode': mode},
      parser: (json) => BackendScrapeJobResponse.fromJson(json),
    );
  }

  Future<List<BackendScrapeJobResponse>> listScrapeJobs(String username, {int limit = 5}) async {
    final uri = await _buildUri('/scrape-jobs', queryParameters: {
      'username': username,
      'limit': '$limit',
    });
    final data = await _sendRequest(uri, method: 'GET');
    final decoded = jsonDecode(data) as List<dynamic>;
    return decoded
        .map((entry) => BackendScrapeJobResponse.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<BackendKifuItemSummaryResponse>> listKifuItems(String username, String jobId, {int limit = 10}) async {
    final uri = await _buildUri('/kifu-items', queryParameters: {
      'username': username,
      'job_id': jobId,
      'limit': '$limit',
    });
    final data = await _sendRequest(uri, method: 'GET');
    final decoded = jsonDecode(data) as List<dynamic>;
    return decoded
        .map((entry) => BackendKifuItemSummaryResponse.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> deleteTrackedUser(String username) async {
    final encoded = Uri.encodeComponent(username);
    final uri = await _buildUri('/tracked-sources/$encoded');
    await _sendRequest(uri, method: 'DELETE');
  }

  Future<bool> healthCheck() async {
    try {
      final uri = await _buildUri('/health');
      await _sendRequest(uri, method: 'GET');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<T> _sendJsonRequest<T>(
    String path, {
    required String method,
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic> json) parser,
  }) async {
    final uri = await _buildUri(path);
    final data = await _sendRequest(uri, method: method, body: jsonEncode(body));
    return parser(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<Uri> _buildUri(String path, {Map<String, String>? queryParameters}) async {
    final rawBaseUrl = await baseUrl;
    final normalized = normalizeBaseUrl(rawBaseUrl);
    if (normalized == null) {
      throw ShogiExtendBackendException('バックエンドURLが不正です');
    }
    final baseUri = Uri.parse(normalized);
    final pathSegments = <String>[
      ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
      ...path.split('/').where((segment) => segment.isNotEmpty),
    ];
    return baseUri.replace(pathSegments: pathSegments, queryParameters: queryParameters);
  }

  Future<String> _sendRequest(Uri uri, {required String method, String? body}) async {
    final request = await _client.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(body);
    }
    final response = await request.close();
    final data = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ShogiExtendBackendException('バックエンド通信に失敗しました (HTTP ${response.statusCode})');
    }
    return data;
  }
}
