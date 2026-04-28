import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/saved_kif_list_sheet.dart';
import 'package:flutter_app/services/kifu_storage_service.dart';

void main() {
  testWidgets('opens paste sheet and imports pasted text', (tester) async {
    final service = _FakeKifuStorageService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedKifListSheet(
            storageService: service,
            onOpen: (_) {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('保存済み棋譜はまだありません'), findsOneWidget);

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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedKifListSheet(
            storageService: service,
            onOpen: (_) {},
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
}

class _FakeKifuStorageService extends KifuStorageService {
  _FakeKifuStorageService()
      : super(
          documentsDirectoryProvider: () async => Directory.systemTemp,
          temporaryDirectoryProvider: () async => Directory.systemTemp,
        );
  final List<String> importedTexts = <String>[];
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
}