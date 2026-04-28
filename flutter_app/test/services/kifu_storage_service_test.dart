import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/models/shogi_models.dart';
import 'package:flutter_app/services/kifu_codec.dart';
import 'package:flutter_app/services/kifu_storage_service.dart';

void main() {
  test('saved file model exposes title and metadata', () async {
    final tempDir = await Directory.systemTemp.createTemp('kifu-storage-test');
    addTearDown(() => tempDir.delete(recursive: true));

    final file = File('${tempDir.path}${Platform.pathSeparator}example.kif');
    await file.writeAsString('dummy');
    final stat = await file.stat();

    final entry = SavedKifFile(
      file: file,
      title: 'example',
      modifiedAt: stat.modified,
    );

    expect(entry.title, 'example');
    expect(entry.file.path.endsWith('example.kif'), isTrue);
  });

  test('importText saves normalized KIF and it can be listed and loaded', () async {
    final tempDir = await Directory.systemTemp.createTemp('kifu-storage-import-test');
    addTearDown(() => tempDir.delete(recursive: true));

    final service = KifuStorageService(
      documentsDirectoryProvider: () async => tempDir,
      temporaryDirectoryProvider: () async => tempDir,
    );
    final text = KifuCodec.encode(_sampleRecord());

    final savedFile = await service.importText(text);
    final savedEntries = await service.listSavedFiles();
    final loadedRecord = await service.loadRecord(savedFile);

    expect(savedEntries, hasLength(1));
    expect(savedEntries.single.file.path, savedFile.path);
    expect(savedEntries.single.title, isNotEmpty);
    expect(loadedRecord.snapshot.winner, ShogiPlayer.sente);
    expect(loadedRecord.snapshot.winner, ShogiPlayer.sente);
    expect(loadedRecord.snapshot.winReason, '投了');
    expect(loadedRecord.snapshot.moveRecords, contains('先手 7七 歩 → 7六'));
  });
}

PersistedShogiGameRecord _sampleRecord() {
  return PersistedShogiGameRecord(
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
}