import 'package:flutter/material.dart';

import '../../services/shogi_extend_backend_service.dart';
import '../../services/shogi_wars_user_store.dart';
import '../../services/url_source_store.dart';
import '../../shared/theme/app_palette.dart';

class URLRegistrationSheet extends StatefulWidget {
  const URLRegistrationSheet({
    super.key,
    required this.urlSourceStore,
    this.userStore,
    this.backendService,
  });

  final URLSourceStore urlSourceStore;
  final ShogiWarsUserStore? userStore;
  final ShogiExtendBackendService? backendService;

  @override
  State<URLRegistrationSheet> createState() => _URLRegistrationSheetState();
}

class _URLRegistrationSheetState extends State<URLRegistrationSheet> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _backendController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  String? _urlErrorMessage;
  String? _backendErrorMessage;
  String? _usernameErrorMessage;
  bool _isRegisteringUrl = false;
  bool _isRegisteringUser = false;
  bool _isTestingBackend = false;

  bool get _supportsBackendSync => widget.userStore != null && widget.backendService != null;

  @override
  void initState() {
    super.initState();
    _loadBackendUrl();
  }

  Future<void> _loadBackendUrl() async {
    if (!_supportsBackendSync) {
      return;
    }
    final current = await widget.backendService!.baseUrl;
    if (!mounted) {
      return;
    }
    _backendController.text = current;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _backendController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _registerUrl() async {
    setState(() {
      _isRegisteringUrl = true;
      _urlErrorMessage = null;
    });
    final result = await widget.urlSourceStore.add(_urlController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _isRegisteringUrl = false;
    });
    if (result.isSuccess) {
      Navigator.of(context).pop('url-added');
      return;
    }
    setState(() {
      _urlErrorMessage = switch (result) {
        URLSourceAddResult.empty => 'URLを入力してください',
        URLSourceAddResult.invalidFormat => '有効なURLを入力してください',
        URLSourceAddResult.duplicate => 'このURLはすでに登録済みです',
        URLSourceAddResult.unsupportedProvider => '対応するURLを入力してください',
        URLSourceAddResult.added => null,
      };
    });
  }

  Future<void> _healthCheckBackend() async {
    final backendService = widget.backendService;
    if (backendService == null) {
      return;
    }
    setState(() {
      _isTestingBackend = true;
      _backendErrorMessage = null;
    });
    final normalized = backendService.normalizeBaseUrl(_backendController.text);
    if (normalized == null) {
      setState(() {
        _isTestingBackend = false;
        _backendErrorMessage = 'http または https の有効な URL を入力してください';
      });
      return;
    }
    await backendService.saveBaseUrl(normalized);
    final ok = await backendService.healthCheck();
    if (!mounted) {
      return;
    }
    setState(() {
      _isTestingBackend = false;
      _backendErrorMessage = ok ? null : 'backend に接続できませんでした';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'backend 接続成功' : 'backend 接続失敗')),
    );
  }

  Future<void> _registerUserAndSync() async {
    final backendService = widget.backendService;
    final userStore = widget.userStore;
    if (backendService == null || userStore == null) {
      return;
    }

    setState(() {
      _isRegisteringUser = true;
      _backendErrorMessage = null;
      _usernameErrorMessage = null;
    });

    final normalizedBaseUrl = backendService.normalizeBaseUrl(_backendController.text);
    final normalizedUsername = userStore.normalizeUsername(_usernameController.text);
    if (normalizedBaseUrl == null || normalizedUsername == null) {
      setState(() {
        _isRegisteringUser = false;
        _backendErrorMessage = normalizedBaseUrl == null ? 'http または https の有効な URL を入力してください' : null;
        _usernameErrorMessage = normalizedUsername == null ? '英数字、アンダースコア、ハイフンのみ使えます' : null;
      });
      return;
    }

    try {
      await backendService.saveBaseUrl(normalizedBaseUrl);
      await backendService.registerTrackedUser(normalizedUsername);

      final validation = await userStore.validationResult(normalizedUsername);
      if (validation == null) {
        await userStore.add(normalizedUsername);
      } else if (validation != ShogiWarsUserAddResult.duplicate) {
        throw StateError(
          switch (validation) {
            ShogiWarsUserAddResult.empty => 'ユーザー名を入力してください',
            ShogiWarsUserAddResult.invalidUsername => '英数字、アンダースコア、ハイフンのみ使えます',
            ShogiWarsUserAddResult.backendUnavailable => 'backend に接続できませんでした',
            ShogiWarsUserAddResult.added => '登録状態を確認できませんでした',
            ShogiWarsUserAddResult.duplicate => 'このユーザーはすでに登録済みです',
          },
        );
      }

      await backendService.enqueueScrapeJob(normalizedUsername);
    } on ShogiExtendBackendException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRegisteringUser = false;
        _backendErrorMessage = error.message;
      });
      return;
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRegisteringUser = false;
        _usernameErrorMessage = error.message;
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isRegisteringUser = false;
    });
    Navigator.of(context).pop('sync-started');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
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
            child: Column(
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
                            _supportsBackendSync ? 'URL / 連携登録' : 'URL登録',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppPalette.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _supportsBackendSync
                                ? 'URL 登録と、将棋ウォーズ username の同期開始をまとめて行えます。'
                                : 'ウォーズ / 81道場 / ShogiDB2 などの URL を登録します。',
                            style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onChanged: (_) {
                    if (_urlErrorMessage != null) {
                      setState(() {
                        _urlErrorMessage = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    filled: true,
                    fillColor: AppPalette.surface,
                    errorText: _urlErrorMessage,
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isRegisteringUrl ? null : _registerUrl,
                    icon: _isRegisteringUrl
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.add_link_rounded),
                    label: Text(_isRegisteringUrl ? '登録中...' : 'URLを登録'),
                  ),
                ),
                if (_supportsBackendSync) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),
                  Text(
                    '将棋ウォーズ連携',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppPalette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'backend URL と username を入力すると、登録と最新棋譜の取得を開始します。',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _backendController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onChanged: (_) {
                      if (_backendErrorMessage != null) {
                        setState(() {
                          _backendErrorMessage = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: BackendSettingsStore.defaultBaseUrl,
                      filled: true,
                      fillColor: AppPalette.surface,
                      errorText: _backendErrorMessage,
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
                  TextField(
                    controller: _usernameController,
                    autocorrect: false,
                    onChanged: (_) {
                      if (_usernameErrorMessage != null) {
                        setState(() {
                          _usernameErrorMessage = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'chubby_cat',
                      filled: true,
                      fillColor: AppPalette.surface,
                      errorText: _usernameErrorMessage,
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTestingBackend || _isRegisteringUser ? null : _healthCheckBackend,
                          icon: _isTestingBackend
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.2),
                                )
                              : const Icon(Icons.health_and_safety_outlined),
                          label: const Text('接続テスト'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isRegisteringUser || _isTestingBackend ? null : _registerUserAndSync,
                          icon: _isRegisteringUser
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.2),
                                )
                              : const Icon(Icons.sync_rounded),
                          label: Text(_isRegisteringUser ? '開始中...' : '登録して同期'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}