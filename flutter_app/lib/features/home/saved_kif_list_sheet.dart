import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/shogi_models.dart';
import '../../services/kifu_storage_service.dart';
import '../../services/url_source_store.dart';
import '../../shared/theme/app_palette.dart';
import 'url_registration_sheet.dart';

class SavedKifListSheet extends StatefulWidget {
  const SavedKifListSheet({
    super.key,
    required this.storageService,
    required this.urlSourceStore,
    required this.onOpen,
  });

  final KifuStorageService storageService;
  final URLSourceStore urlSourceStore;
  final ValueChanged<SavedKifFile> onOpen;

  @override
  State<SavedKifListSheet> createState() => _SavedKifListSheetState();
}

class _SavedKifListSheetState extends State<SavedKifListSheet> {
  late Future<List<SavedKifFile>> _future;
  late Future<List<RegisteredKifuSource>> _sourceFuture;
  bool _isImporting = false;
  final TextEditingController _pasteController = TextEditingController();
  bool _isImportingPastedText = false;

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _future = widget.storageService.listSavedFiles();
    _sourceFuture = widget.urlSourceStore.load();
  }

  void _reload() {
    setState(() {
      _future = widget.storageService.listSavedFiles();
      _sourceFuture = widget.urlSourceStore.load();
    });
  }

  Future<void> _delete(SavedKifFile entry) async {
    await widget.storageService.deleteSavedFile(entry.file);
    _reload();
  }

  Future<void> _deleteSource(RegisteredKifuSource entry) async {
    await widget.urlSourceStore.remove(entry.id);
    _reload();
  }

  Future<void> _showRegistrationSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => URLRegistrationSheet(urlSourceStore: widget.urlSourceStore),
    );
    if (added == true && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL を登録しました')),
      );
    }
  }

  Future<void> _importFile() async {
    const typeGroup = XTypeGroup(
      label: 'kifu',
      extensions: ['kif', 'csa', 'txt'],
    );
    final selected = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _isImporting = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      final text = await selected.readAsString();
      await widget.storageService.importText(text);
      _reload();
      messenger.showSnackBar(
        SnackBar(content: Text('${selected.name} を取り込みました')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('棋譜の取り込みに失敗しました: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _importPastedText() async {
    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isImportingPastedText = true;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.storageService.importText(text);
      _pasteController.clear();
      _reload();
      if (mounted) {
        navigator.pop();
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('貼り付けた棋譜を取り込みました')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('棋譜の取り込みに失敗しました: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImportingPastedText = false;
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (!mounted) {
      return;
    }
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クリップボードにテキストがありません')),
      );
      return;
    }

    _pasteController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _showPasteSheet() {
    _pasteController.clear();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppPalette.cardBg,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: AppPalette.shadow,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  Future<void> runImport() async {
                    setModalState(() {
                      _isImportingPastedText = true;
                    });
                    await _importPastedText();
                    if (mounted) {
                      setModalState(() {
                        _isImportingPastedText = false;
                      });
                    }
                  }

                  Future<void> runPaste() async {
                    await _pasteFromClipboard();
                    if (mounted) {
                      setModalState(() {});
                    }
                  }

                  final hasText = _pasteController.text.trim().isNotEmpty;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '棋譜を貼り付け',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: AppPalette.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'KIF / CSA テキストを貼り付けてそのまま保存一覧へ取り込みます。',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppPalette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pasteController,
                        maxLines: 12,
                        minLines: 10,
                        onChanged: (_) => setModalState(() {}),
                        decoration: InputDecoration(
                          hintText: 'ここに KIF / CSA テキストを貼り付けます',
                          filled: true,
                          fillColor: AppPalette.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AppPalette.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AppPalette.outline),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isImportingPastedText ? null : runPaste,
                              icon: const Icon(Icons.content_paste_rounded),
                              label: const Text('ペースト'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isImportingPastedText || !hasText
                                  ? null
                                  : () {
                                      _pasteController.clear();
                                      setModalState(() {});
                                    },
                              icon: const Icon(Icons.clear_rounded),
                              label: const Text('クリア'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isImportingPastedText || !hasText ? null : runImport,
                          icon: _isImportingPastedText
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.2),
                                )
                              : const Icon(Icons.playlist_add_check_rounded),
                          label: Text(_isImportingPastedText ? '取り込み中...' : '取り込む'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.cardBg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: AppPalette.shadow,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '保存棋譜',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppPalette.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '保存済み KIF と登録済み URL ソースをまとめて管理できます。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppPalette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _showRegistrationSheet,
                      icon: const Icon(Icons.add_link_rounded),
                    ),
                    IconButton(
                      onPressed: _isImporting ? null : _importFile,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : const Icon(Icons.note_add_outlined),
                    ),
                    IconButton(
                      onPressed: _isImportingPastedText ? null : _showPasteSheet,
                      icon: const Icon(Icons.content_paste_go_rounded),
                    ),
                    IconButton(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: FutureBuilder<List<SavedKifFile>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 36),
                            const SizedBox(height: 12),
                            Text('一覧の読み込みに失敗しました: ${snapshot.error}'),
                          ],
                        ),
                      );
                    }

                    final items = snapshot.data ?? const <SavedKifFile>[];
                    return FutureBuilder<List<RegisteredKifuSource>>(
                      future: _sourceFuture,
                      builder: (context, sourceSnapshot) {
                        final sources = sourceSnapshot.data ?? const <RegisteredKifuSource>[];
                        if (items.isEmpty && sources.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.fromLTRB(24, 20, 24, 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.menu_book_outlined, size: 40, color: Color(0xFF8C6D5A)),
                                
                                SizedBox(height: 12),
                                Text('保存棋譜と登録 URL はまだありません'),
                              ],
                            ),
                          );
                        }

                        return ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          children: [
                            if (items.isNotEmpty) ...[
                              _SectionTitle(label: '保存棋譜'),
                              const SizedBox(height: 10),
                              ...items.map(_buildSavedFileTile),
                            ],
                            if (items.isNotEmpty && sources.isNotEmpty) const SizedBox(height: 18),
                            if (sources.isNotEmpty) ...[
                              _SectionTitle(label: '登録 URL'),
                              const SizedBox(height: 10),
                              ...sources.map(_buildSourceTile),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}/${two(value.month)}/${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }

  Widget _buildSavedFileTile(SavedKifFile entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppPalette.outline),
        ),
        child: ListTile(
          title: Text(
            entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(_formatDate(entry.modifiedAt)),
          leading: const Icon(Icons.description_outlined),
          trailing: IconButton(
            onPressed: () => _delete(entry),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          onTap: () {
            widget.onOpen(entry);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Widget _buildSourceTile(RegisteredKifuSource entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppPalette.outline),
        ),
        child: ListTile(
          title: Text(entry.hostLabel),
          subtitle: Text(entry.urlString, maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: CircleAvatar(
            backgroundColor: AppPalette.info.withValues(alpha: 0.12),
            child: Text(
              entry.provider.label,
              style: const TextStyle(fontSize: 10, color: AppPalette.textSecondary),
            ),
          ),
          trailing: IconButton(
            onPressed: () => _deleteSource(entry),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppPalette.textPrimary,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}