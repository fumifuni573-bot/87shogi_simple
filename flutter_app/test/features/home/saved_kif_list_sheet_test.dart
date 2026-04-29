import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/models/shogi_models.dart';
import 'package:flutter_app/features/home/saved_kif_list_sheet.dart';
import 'package:flutter_app/services/kifu_storage_service.dart';
import 'package:flutter_app/services/scraped_kifu_catalog.dart';
import 'package:flutter_app/services/scraped_kifu_view_settings_store.dart';
import 'package:flutter_app/services/shogi_extend_backend_service.dart';
import 'package:flutter_app/services/shogi_wars_user_store.dart';
import 'package:flutter_app/services/url_source_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('opens paste sheet and imports pasted text', (tester) async {
    final service = _FakeKifuStorageService();
    final backendService = _FakeBackendService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedKifListSheet(
            storageService: service,
            urlSourceStore: URLSourceStore(),
            userStore: ShogiWarsUserStore(),
            backendService: backendService,
            scrapedCatalog: LocalScrapedKifuCatalog(),
            onOpen: (_) async {},
            onOpenScraped: (item) async {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('保存棋譜、登録 URL、登録ユーザーはまだありません'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('棋譜を貼り付け'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      '開始日時：2026/04/28 09:30:15\n手合割：平手\n先手：先手太郎\n後手：後手花子\n結果：先手の勝ち（投了）\n手数----指手---------\n1 ７六歩(77)\n2 ３四歩(33)\n3 投了',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, '取り込む'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.importedTexts, hasLength(1));
    expect(service.importedTexts.single, contains('1 ７六歩(77)'));
    expect(find.text('貼り付けた棋譜を取り込みました'), findsOneWidget);
    expect(find.text('sample-imported'), findsOneWidget);
  });

  testWidgets('paste import button stays disabled for empty text', (tester) async {
    final service = _FakeKifuStorageService();
    final backendService = _FakeBackendService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedKifListSheet(
            storageService: service,
            urlSourceStore: URLSourceStore(),
            userStore: ShogiWarsUserStore(),
            backendService: backendService,
            scrapedCatalog: LocalScrapedKifuCatalog(),
            onOpen: (_) async {},
            onOpenScraped: (item) async {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final importButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '取り込む'));
    expect(importButton.onPressed, isNull);
    expect(service.importedTexts, isEmpty);
  });

  testWidgets('shows scraped item replay action and invokes callback', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'registered_shogi_wars_users_v1':
          '[{"id":"1","username":"chubby_cat","createdAt":"2026-04-30T09:00:00.000"}]',
    });
    final service = _FakeKifuStorageService();
    final backendService = _FakeBackendService(
      jobsByUsername: <String, List<BackendScrapeJobResponse>>{
        'chubby_cat': <BackendScrapeJobResponse>[
          const BackendScrapeJobResponse(
            id: 'job-1',
            username: 'chubby_cat',
            mode: 'incremental',
            status: 'succeeded',
          ),
        ],
      },
      itemsByUsername: <String, List<BackendKifuItemSummaryResponse>>{
        'chubby_cat': <BackendKifuItemSummaryResponse>[
          BackendKifuItemSummaryResponse(
            id: 'item-1',
            username: 'chubby_cat',
            jobId: 'job-1',
            sourceGameId: 'game-1',
            sourceGameUrl: 'https://www.shogi-extend.com/swars/battles/game-1',
            searchedPage: 1,
            scrapedAt: DateTime(2026, 4, 30, 10, 0),
            players: const <String, String?>{'sente': 'chubby_cat', 'gote': 'mikyun'},
            result: '先手勝ち',
          ),
        ],
      },
      detailsByItemId: <String, BackendKifuItemDetailResponse>{
        'item-1': BackendKifuItemDetailResponse(
          id: 'item-1',
          username: 'chubby_cat',
          jobId: 'job-1',
          sourceGameId: 'game-1',
          sourceGameUrl: 'https://www.shogi-extend.com/swars/battles/game-1',
          searchedPage: 1,
          scrapedAt: DateTime(2026, 4, 30, 10, 0),
          players: const <String, String?>{'sente': 'chubby_cat', 'gote': 'mikyun'},
          result: '先手勝ち',
          kifText:
              '開始日時：2026/04/30 10:00:00\n手合割：平手\n先手：chubby_cat\n後手：mikyun\n結果：先手の勝ち（投了）\n手数----指手---------\n1 ７六歩(77)\n2 ３四歩(33)\n3 投了',
          metadata: const <String, dynamic>{'battle_key': 'game-1'},
        ),
      },
    );
    ScrapedKifuRecord? callbackItem;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedKifListSheet(
            storageService: service,
            urlSourceStore: URLSourceStore(),
            userStore: ShogiWarsUserStore(),
            backendService: backendService,
            scrapedCatalog: LocalScrapedKifuCatalog(),
            onOpen: (_) async {},
            onOpenScraped: (item) async {
              callbackItem = item;
            },
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('取り込み結果'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '再現'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '再現'));
    await tester.pump();

    expect(callbackItem?.username, 'chubby_cat');
    expect(callbackItem?.id, 'item-1');
    expect(callbackItem?.kifText, contains('1 ７六歩(77)'));
  });

  testWidgets('shows recent user items even when the latest job has no inserted items', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'registered_shogi_wars_users_v1':
          '[{"id":"1","username":"chubby_cat","createdAt":"2026-04-30T09:00:00.000"}]',
    });

    final backendService = _FakeBackendService(
      jobsByUsername: <String, List<BackendScrapeJobResponse>>{
        'chubby_cat': <BackendScrapeJobResponse>[
          const BackendScrapeJobResponse(
            id: 'job-latest',
            username: 'chubby_cat',
            mode: 'incremental',
            status: 'succeeded',
            insertedGames: 0,
            skippedGames: 10,
          ),
        ],
      },
      itemsByUsername: <String, List<BackendKifuItemSummaryResponse>>{
        'chubby_cat': <BackendKifuItemSummaryResponse>[
          BackendKifuItemSummaryResponse(
            id: 'item-old-1',
            username: 'chubby_cat',
            jobId: 'job-older',
            sourceGameId: 'game-old-1',
            sourceGameUrl: 'https://www.shogi-extend.com/swars/battles/game-old-1',
            searchedPage: 1,
            scrapedAt: DateTime(2026, 4, 30, 10, 0),
            players: const <String, String?>{'sente': 'chubby_cat', 'gote': 'mikyun'},
            result: '先手勝ち',
          ),
        ],
      },
      detailsByItemId: <String, BackendKifuItemDetailResponse>{
        'item-old-1': BackendKifuItemDetailResponse(
          id: 'item-old-1',
          username: 'chubby_cat',
          jobId: 'job-older',
          sourceGameId: 'game-old-1',
          sourceGameUrl: 'https://www.shogi-extend.com/swars/battles/game-old-1',
          searchedPage: 1,
          scrapedAt: DateTime(2026, 4, 30, 10, 0),
          players: const <String, String?>{'sente': 'chubby_cat', 'gote': 'mikyun'},
          result: '先手勝ち',
          kifText:
              '開始日時：2026/04/30 10:00:00\n手合割：平手\n先手：chubby_cat\n後手：mikyun\n結果：先手の勝ち（投了）\n手数----指手---------\n1 ７六歩(77)',
          metadata: const <String, dynamic>{'battle_key': 'game-old-1'},
        ),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedKifListSheet(
            storageService: _FakeKifuStorageService(),
            urlSourceStore: URLSourceStore(),
            userStore: ShogiWarsUserStore(),
            backendService: backendService,
            scrapedCatalog: LocalScrapedKifuCatalog(),
            onOpen: (_) async {},
            onOpenScraped: (item) async {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('取り込み結果'), findsOneWidget);
    expect(find.textContaining('chubby_cat vs mikyun'), findsOneWidget);
  });

  testWidgets('changes scraped item display limit and persists the selection', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'registered_shogi_wars_users_v1':
          '[{"id":"1","username":"chubby_cat","createdAt":"2026-04-30T09:00:00.000"}]',
      'scraped_kifu_limit_per_user_v1': 5,
    });

    final backendService = _FakeBackendService(
      jobsByUsername: <String, List<BackendScrapeJobResponse>>{
        'chubby_cat': <BackendScrapeJobResponse>[
          const BackendScrapeJobResponse(
            id: 'job-1',
            username: 'chubby_cat',
            mode: 'incremental',
            status: 'succeeded',
          ),
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedKifListSheet(
            storageService: _FakeKifuStorageService(),
            urlSourceStore: URLSourceStore(),
            userStore: ShogiWarsUserStore(),
            backendService: backendService,
            scrapedCatalog: LocalScrapedKifuCatalog(),
            viewSettingsStore: ScrapedKifuViewSettingsStore(),
            onOpen: (_) async {},
            onOpenScraped: (item) async {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('表示 5 件'), findsOneWidget);

    await tester.tap(find.text('表示 5 件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('表示 20 件').last);
    await tester.pumpAndSettle();

    expect(find.text('表示 20 件'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('scraped_kifu_limit_per_user_v1'), 20);
  });

  testWidgets('shows scraped item save action and stores the record', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'registered_shogi_wars_users_v1':
          '[{"id":"1","username":"chubby_cat","createdAt":"2026-04-30T09:00:00.000"}]',
    });
    final service = _FakeKifuStorageService();
    final backendService = _FakeBackendService(
      jobsByUsername: <String, List<BackendScrapeJobResponse>>{
        'chubby_cat': <BackendScrapeJobResponse>[
          const BackendScrapeJobResponse(
            id: 'job-1',
            username: 'chubby_cat',
            mode: 'incremental',
            status: 'succeeded',
          ),
        ],
      },
      itemsByUsername: <String, List<BackendKifuItemSummaryResponse>>{
        'chubby_cat': <BackendKifuItemSummaryResponse>[
          BackendKifuItemSummaryResponse(
            id: 'item-1',
            username: 'chubby_cat',
            jobId: 'job-1',
            sourceGameId: 'game-1',
            sourceGameUrl: 'https://www.shogi-extend.com/swars/battles/game-1',
            searchedPage: 1,
            scrapedAt: DateTime(2026, 4, 30, 10, 0),
            players: const <String, String?>{'sente': 'chubby_cat', 'gote': 'mikyun'},
            result: '先手勝ち',
          ),
        ],
      },
      detailsByItemId: <String, BackendKifuItemDetailResponse>{
        'item-1': BackendKifuItemDetailResponse(
          id: 'item-1',
          username: 'chubby_cat',
          jobId: 'job-1',
          sourceGameId: 'game-1',
          sourceGameUrl: 'https://www.shogi-extend.com/swars/battles/game-1',
          searchedPage: 1,
          scrapedAt: DateTime(2026, 4, 30, 10, 0),
          players: const <String, String?>{'sente': 'chubby_cat', 'gote': 'mikyun'},
          result: '先手勝ち',
          kifText:
              '開始日時：2026/04/30 10:00:00\n手合割：平手\n先手：chubby_cat\n後手：mikyun\n結果：先手の勝ち（投了）\n手数----指手---------\n1 ７六歩(77)\n2 ３四歩(33)\n3 投了',
          metadata: const <String, dynamic>{'battle_key': 'game-1'},
        ),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedKifListSheet(
            storageService: service,
            urlSourceStore: URLSourceStore(),
            userStore: ShogiWarsUserStore(),
            backendService: backendService,
            scrapedCatalog: LocalScrapedKifuCatalog(),
            onOpen: (_) async {},
            onOpenScraped: (item) async {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.widgetWithText(OutlinedButton, '保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(service.savedRecords, hasLength(1));
    expect(find.text('saved-from-scraped'), findsOneWidget);
  });

  testWidgets('renames a saved file from the explicit action button', (tester) async {
    final service = _FakeKifuStorageService.withSavedFiles(
      <SavedKifFile>[
        SavedKifFile(
          file: File('${Directory.systemTemp.path}${Platform.pathSeparator}before-rename.kif'),
          title: 'before-rename',
          modifiedAt: DateTime(2026, 4, 30, 12, 0),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedKifListSheet(
            storageService: service,
            urlSourceStore: URLSourceStore(),
            userStore: ShogiWarsUserStore(),
            backendService: _FakeBackendService(),
            scrapedCatalog: LocalScrapedKifuCatalog(),
            onOpen: (_) async {},
            onOpenScraped: (item) async {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, '名前変更'));
    await tester.pumpAndSettle();

    expect(find.text('棋譜名を変更'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'after-rename');
    await tester.tap(find.widgetWithText(FilledButton, '変更する'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.renamedTitles, <String>['after-rename']);
    expect(find.text('after-rename'), findsOneWidget);
    expect(find.text('before-rename'), findsNothing);
    expect(find.text('棋譜名を変更しました'), findsOneWidget);
  });

  testWidgets('deletes a saved file from the explicit action button', (tester) async {
    final service = _FakeKifuStorageService.withSavedFiles(
      <SavedKifFile>[
        SavedKifFile(
          file: File('${Directory.systemTemp.path}${Platform.pathSeparator}delete-target.kif'),
          title: 'delete-target',
          modifiedAt: DateTime(2026, 4, 30, 12, 0),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedKifListSheet(
            storageService: service,
            urlSourceStore: URLSourceStore(),
            userStore: ShogiWarsUserStore(),
            backendService: _FakeBackendService(),
            scrapedCatalog: LocalScrapedKifuCatalog(),
            onOpen: (_) async {},
            onOpenScraped: (item) async {},
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('delete-target'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '削除'));
    await tester.pumpAndSettle();

    expect(service.deletedPaths.single, contains('delete-target.kif'));
    expect(find.text('delete-target'), findsNothing);
  });
}

class _FakeKifuStorageService extends KifuStorageService {
  _FakeKifuStorageService({List<SavedKifFile>? initialSavedFiles})
      : super(
          documentsDirectoryProvider: () async => Directory.systemTemp,
          temporaryDirectoryProvider: () async => Directory.systemTemp,
        ) {
    if (initialSavedFiles != null) {
      _savedFiles.addAll(initialSavedFiles);
    }
  }

  _FakeKifuStorageService.withSavedFiles(List<SavedKifFile> initialSavedFiles)
      : this(initialSavedFiles: initialSavedFiles);

  final List<String> importedTexts = <String>[];
  final List<PersistedShogiGameRecord> savedRecords = <PersistedShogiGameRecord>[];
  final List<String> renamedTitles = <String>[];
  final List<String> deletedPaths = <String>[];
  final List<SavedKifFile> _savedFiles = <SavedKifFile>[];

  @override
  Future<List<SavedKifFile>> listSavedFiles() async => List<SavedKifFile>.from(_savedFiles);

  @override
  Future<File> importText(String text) async {
    importedTexts.add(text);
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}sample-imported.kif');
    _savedFiles
      ..clear()
      ..add(
        SavedKifFile(
          file: file,
          title: 'sample-imported',
          modifiedAt: DateTime(2026, 4, 28, 12, 0),
        ),
      );
    return file;
  }

  @override
  Future<File> saveToLibrary(PersistedShogiGameRecord record) async {
    savedRecords.add(record);
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}saved-from-scraped.kif');
    _savedFiles
      ..clear()
      ..add(
        SavedKifFile(
          file: file,
          title: 'saved-from-scraped',
          modifiedAt: DateTime(2026, 4, 30, 12, 0),
        ),
      );
    return file;
  }

  @override
  Future<File> renameSavedFile(File file, String rawTitle) async {
    renamedTitles.add(rawTitle);
    final renamedFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}$rawTitle.kif');
    final currentIndex = _savedFiles.indexWhere((entry) => entry.file.path == file.path);
    if (currentIndex != -1) {
      _savedFiles[currentIndex] = SavedKifFile(
        file: renamedFile,
        title: rawTitle,
        modifiedAt: DateTime(2026, 4, 30, 12, 1),
      );
    }
    return renamedFile;
  }

  @override
  Future<void> deleteSavedFile(File file) async {
    deletedPaths.add(file.path);
    _savedFiles.removeWhere((entry) => entry.file.path == file.path);
  }
}

class _FakeBackendService extends ShogiExtendBackendService {
  _FakeBackendService({
    this.jobsByUsername = const <String, List<BackendScrapeJobResponse>>{},
    this.itemsByUsername = const <String, List<BackendKifuItemSummaryResponse>>{},
    this.detailsByItemId = const <String, BackendKifuItemDetailResponse>{},
  });

  final Map<String, List<BackendScrapeJobResponse>> jobsByUsername;
  final Map<String, List<BackendKifuItemSummaryResponse>> itemsByUsername;
  final Map<String, BackendKifuItemDetailResponse> detailsByItemId;

  @override
  Future<List<BackendScrapeJobResponse>> listScrapeJobs(String username, {int limit = 5}) async {
    return jobsByUsername[username] ?? const <BackendScrapeJobResponse>[];
  }

  @override
  Future<List<BackendKifuItemSummaryResponse>> listKifuItems(String username, String? jobId, {int limit = 10}) async {
    return itemsByUsername[username] ?? const <BackendKifuItemSummaryResponse>[];
  }

  @override
  Future<BackendKifuItemDetailResponse> getKifuItemDetail(String username, String itemId) async {
    final detail = detailsByItemId[itemId];
    if (detail == null) {
      throw StateError('missing detail for $itemId');
    }
    return detail;
  }
}