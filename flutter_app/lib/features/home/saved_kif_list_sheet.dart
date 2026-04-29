import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/shogi_models.dart';
import '../../services/kifu_storage_service.dart';
import '../../services/shogi_extend_backend_service.dart';
import '../../services/shogi_wars_user_store.dart';
import '../../services/url_source_store.dart';
import '../../shared/theme/app_palette.dart';
import 'shogi_extend_backend_settings_sheet.dart';
import 'shogi_wars_user_registration_sheet.dart';
import 'url_registration_sheet.dart';

class SavedKifListSheet extends StatefulWidget {
  const SavedKifListSheet({
    super.key,
    required this.storageService,
    required this.urlSourceStore,
    required this.userStore,
    required this.backendService,
    required this.onOpen,
  });

  final KifuStorageService storageService;
  final URLSourceStore urlSourceStore;
  final ShogiWarsUserStore userStore;
  final ShogiExtendBackendService backendService;
  final ValueChanged<SavedKifFile> onOpen;

  @override
  State<SavedKifListSheet> createState() => _SavedKifListSheetState();
}

class _SavedKifListSheetState extends State<SavedKifListSheet> {
  late Future<List<SavedKifFile>> _future;
  late Future<List<RegisteredKifuSource>> _sourceFuture;
  late Future<List<RegisteredShogiWarsUser>> _userFuture;
  bool _isImporting = false;
  bool _isImportingPastedText = false;
  bool _isReloadingBackend = false;
  bool _isJobPolling = false;
  final TextEditingController _pasteController = TextEditingController();
  Timer? _pollingTimer;
  Map<String, BackendScrapeJobResponse> _latestJobs = <String, BackendScrapeJobResponse>{};
  Map<String, List<BackendKifuItemSummaryResponse>> _latestItems =
      <String, List<BackendKifuItemSummaryResponse>>{};

  @override
  void initState() {
    super.initState();
    _future = kIsWeb ? Future.value(const <SavedKifFile>[]) : widget.storageService.listSavedFiles();
    _sourceFuture = widget.urlSourceStore.load();
    _userFuture = widget.userStore.load();
    unawaited(_refreshBackendStatuses());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pasteController.dispose();
    super.dispose();
  }

  void _reloadLocal() {
    setState(() {
      _future = kIsWeb ? Future.value(const <SavedKifFile>[]) : widget.storageService.listSavedFiles();
      _sourceFuture = widget.urlSourceStore.load();
      _userFuture = widget.userStore.load();
    });
  }

  Future<void> _reloadAll() async {
    _reloadLocal();
    setState(() {
      _isReloadingBackend = true;
    });

    final users = await widget.userStore.load();
    int startedCount = 0;
    int failedCount = 0;
    for (final user in users) {
      try {
        await widget.backendService.registerTrackedUser(user.username);
        await widget.backendService.enqueueScrapeJob(user.username);
        startedCount += 1;
      } catch (_) {
        failedCount += 1;
      }
    }

    await _refreshBackendStatuses();
    if (!mounted) {
      return;
    }
    setState(() {
      _isReloadingBackend = false;
    });
    if (startedCount > 0 || failedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ユーザー同期: $startedCount件開始 / $failedCount件失敗')),
      );
    }
  }

  Future<void> _delete(SavedKifFile entry) async {
    if (kIsWeb) {
      return;
    }
    await widget.storageService.deleteSavedFile(entry.file);
    _reloadLocal();
  }

  Future<void> _deleteSource(RegisteredKifuSource entry) async {
    await widget.urlSourceStore.remove(entry.id);
    _reloadLocal();
  }

  Future<void> _deleteUser(RegisteredShogiWarsUser entry) async {
    try {
      await widget.backendService.deleteTrackedUser(entry.username);
    } catch (_) {
      // Keep the local store as the source of truth if backend delete fails.
    }
    await widget.userStore.remove(entry.id);
    _latestJobs.remove(entry.username);
    _latestItems.remove(entry.username);
    _reloadLocal();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showRegistrationSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => URLRegistrationSheet(urlSourceStore: widget.urlSourceStore),
    );
    if (added == true && mounted) {
      _reloadLocal();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL を登録しました')),
      );
    }
  }

  Future<ShogiWarsUserAddResult> _registerTrackedUser(String username) async {
    final validation = await widget.userStore.validationResult(username);
    if (validation != null) {
      return validation;
    }
    try {
      await widget.backendService.registerTrackedUser(username.trim());
    } catch (_) {
      return ShogiWarsUserAddResult.backendUnavailable;
    }
    final result = await widget.userStore.add(username);
    if (result.isSuccess) {
      _reloadLocal();
      await _refreshBackendStatuses();
    }
    return result;
  }

  Future<void> _showUserRegistrationSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShogiWarsUserRegistrationSheet(onRegister: _registerTrackedUser),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('将棋ウォーズユーザーを登録しました')),
      );
    }
  }

  Future<void> _showBackendSettingsSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShogiExtendBackendSettingsSheet(backendService: widget.backendService),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('backend 設定を保存しました')),
      );
    }
  }

  Future<void> _importFile() async {
    if (kIsWeb) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web ではローカル棋譜ライブラリは未対応です')),
      );
      return;
    }
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
      _reloadLocal();
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
    if (kIsWeb) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web ではローカル棋譜ライブラリは未対応です')),
      );
      return;
    }
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
      _reloadLocal();
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

  Future<void> _refreshBackendStatuses() async {
    final users = await widget.userStore.load();
    if (users.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _latestJobs = <String, BackendScrapeJobResponse>{};
        _latestItems = <String, List<BackendKifuItemSummaryResponse>>{};
        _isJobPolling = false;
      });
      _stopPolling();
      return;
    }

    final nextJobs = <String, BackendScrapeJobResponse>{};
    final nextItems = <String, List<BackendKifuItemSummaryResponse>>{};
    for (final user in users) {
      try {
        final jobs = await widget.backendService.listScrapeJobs(user.username, limit: 1);
        if (jobs.isEmpty) {
          continue;
        }
        final latestJob = jobs.first;
        nextJobs[user.username] = latestJob;
        if (latestJob.status == 'succeeded' || latestJob.status == 'running') {
          final items = await widget.backendService.listKifuItems(user.username, latestJob.id, limit: 5);
          if (items.isNotEmpty) {
            nextItems[user.username] = items;
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _latestJobs = nextJobs;
      _latestItems = nextItems;
      _isJobPolling = nextJobs.values.any((job) => job.isActive);
    });
    if (_isJobPolling) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    if (_pollingTimer != null && _pollingTimer!.isActive) {
      return;
    }
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshBackendStatuses());
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
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
                            '保存済み KIF、登録 URL、登録ユーザー、backend 結果をまとめて管理できます。',
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
                      onPressed: _showUserRegistrationSheet,
                      icon: const Icon(Icons.person_add_alt_rounded),
                    ),
                    IconButton(
                      onPressed: _showBackendSettingsSheet,
                      icon: const Icon(Icons.dns_rounded),
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
                      onPressed: _isReloadingBackend ? null : _reloadAll,
                      icon: _isReloadingBackend
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : const Icon(Icons.refresh_rounded),
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
                        return FutureBuilder<List<RegisteredShogiWarsUser>>(
                          future: _userFuture,
                          builder: (context, userSnapshot) {
                            final users = userSnapshot.data ?? const <RegisteredShogiWarsUser>[];
                            if (items.isEmpty && sources.isEmpty && users.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.fromLTRB(24, 20, 24, 32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.menu_book_outlined, size: 40, color: Color(0xFF8C6D5A)),
                                    SizedBox(height: 12),
                                    Text('保存棋譜、登録 URL、登録ユーザーはまだありません'),
                                  ],
                                ),
                              );
                            }

                            return ListView(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              children: [
                                if (items.isNotEmpty) ...[
                                  const _SectionTitle(label: '保存棋譜'),
                                  const SizedBox(height: 10),
                                  ...items.map(_buildSavedFileTile),
                                ],
                                if (kIsWeb) ...[
                                  if (items.isNotEmpty || sources.isNotEmpty || users.isNotEmpty)
                                    const SizedBox(height: 18),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppPalette.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: AppPalette.outline),
                                    ),
                                    child: Text(
                                      'Web では保存済み棋譜ライブラリの表示は無効です。URL 登録と backend 同期のみ確認できます。',
                                      style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.textSecondary),
                                    ),
                                  ),
                                ],
                                if (items.isNotEmpty && (sources.isNotEmpty || users.isNotEmpty))
                                  const SizedBox(height: 18),
                                if (sources.isNotEmpty) ...[
                                  const _SectionTitle(label: '登録 URL'),
                                  const SizedBox(height: 10),
                                  ...sources.map(_buildSourceTile),
                                ],
                                if (users.isNotEmpty) ...[
                                  if (sources.isNotEmpty) const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      const Expanded(child: _SectionTitle(label: '登録ユーザー')),
                                      if (_isJobPolling) ...[
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '更新中',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: AppPalette.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ...users.map(_buildTrackedUserTile),
                                ],
                              ],
                            );
                          },
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

  Color _jobStatusColor(String status) {
    switch (status) {
      case 'queued':
        return Colors.orange;
      case 'running':
        return AppPalette.info;
      case 'succeeded':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return AppPalette.textSecondary;
    }
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

  Widget _buildTrackedUserTile(RegisteredShogiWarsUser entry) {
    final theme = Theme.of(context);
    final latestJob = _latestJobs[entry.username];
    final importedItems = _latestItems[entry.username] ?? const <BackendKifuItemSummaryResponse>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppPalette.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppPalette.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'ウォーズユーザー',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppPalette.info),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatDate(entry.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.textSecondary),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteUser(entry),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              Text(
                entry.username,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                entry.searchUrlString,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.textSecondary),
              ),
              if (latestJob != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      latestJob.statusLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _jobStatusColor(latestJob.status),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (latestJob.requestedAt != null)
                      Expanded(
                        child: Text(
                          _formatDate(latestJob.requestedAt!.toLocal()),
                          style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.textSecondary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  latestJob.summaryLine,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.textSecondary),
                ),
                if (importedItems.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '取り込み結果',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...importedItems.take(5).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.matchupLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            item.summaryLine,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.textSecondary),
                          ),
                          Text(
                            item.sourceGameUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 10),
                Text(
                  'まだ backend ジョブ履歴はありません',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.textSecondary),
                ),
              ],
            ],
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