import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/models/shogi_models.dart';
import 'kifu_parser.dart';
import 'kifu_codec.dart';

class SavedKifFile {
  const SavedKifFile({
    required this.file,
    required this.title,
    required this.modifiedAt,
  });

  final File file;
  final String title;
  final DateTime modifiedAt;
}

class KifuStorageService {
  KifuStorageService({
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? temporaryDirectoryProvider,
  })  : _documentsDirectoryProvider = documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
        _temporaryDirectoryProvider = temporaryDirectoryProvider ?? getTemporaryDirectory;

  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  Future<Directory> recordsDirectory() async {
    final baseDir = await _documentsDirectoryProvider();
    final recordsDir = Directory('${baseDir.path}${Platform.pathSeparator}kifu_records');
    if (!recordsDir.existsSync()) {
      await recordsDir.create(recursive: true);
    }
    return recordsDir;
  }

  Future<File> saveToLibrary(PersistedShogiGameRecord record) async {
    final recordsDir = await recordsDirectory();
    final file = File('${recordsDir.path}${Platform.pathSeparator}${KifuCodec.fileName(record)}');
    await file.writeAsString(KifuCodec.encode(record), flush: true);
    return file;
  }

  Future<List<SavedKifFile>> listSavedFiles() async {
    final recordsDir = await recordsDirectory();
    final files = recordsDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.kif'))
        .toList(growable: false);

    final entries = <SavedKifFile>[];
    for (final file in files) {
      final stat = await file.stat();
      entries.add(
        SavedKifFile(
          file: file,
          title: file.uri.pathSegments.last.replaceAll('.kif', ''),
          modifiedAt: stat.modified,
        ),
      );
    }

    entries.sort((left, right) => right.modifiedAt.compareTo(left.modifiedAt));
    return entries;
  }

  Future<File> importText(String text) async {
    final record = parseRecordText(text);
    return saveToLibrary(record);
  }

  Future<PersistedShogiGameRecord> loadRecord(File file) async {
    final text = await file.readAsString();
    return parseRecordText(text);
  }

  PersistedShogiGameRecord parseRecordText(String text) {
    return KifuParser.parse(text: text, includeHistory: true).record;
  }

  Future<void> deleteSavedFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> renameSavedFile(File file, String rawTitle) async {
    final normalizedTitle = normalizeTitle(rawTitle);
    if (normalizedTitle == null) {
      throw ArgumentError('名前が空です');
    }
    final currentExtension = file.path.toLowerCase().endsWith('.kif') ? '.kif' : '';
    final targetPath = '${file.parent.path}${Platform.pathSeparator}$normalizedTitle$currentExtension';
    if (file.path == targetPath) {
      return file;
    }
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      throw ArgumentError('同名の棋譜が既にあります');
    }
    return file.rename(targetPath);
  }

  String? normalizeTitle(String rawTitle) {
    final trimmed = rawTitle.trim().replaceAll(RegExp(r'\.kif$', caseSensitive: false), '');
    if (trimmed.isEmpty) {
      return null;
    }
    final sanitized = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return sanitized.isEmpty ? null : sanitized;
  }

  Future<File> exportAndShare(PersistedShogiGameRecord record) async {
    final tempDir = await _temporaryDirectoryProvider();
    final file = File('${tempDir.path}${Platform.pathSeparator}${KifuCodec.fileName(record)}');
    await file.writeAsString(KifuCodec.encode(record), flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/x-kif')],
      text: 'KIF棋譜を共有します',
    );
    return file;
  }
}