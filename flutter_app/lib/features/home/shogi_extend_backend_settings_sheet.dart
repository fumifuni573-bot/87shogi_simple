import 'package:flutter/material.dart';

import '../../services/shogi_extend_backend_service.dart';
import '../../shared/theme/app_palette.dart';

class ShogiExtendBackendSettingsSheet extends StatefulWidget {
  const ShogiExtendBackendSettingsSheet({
    super.key,
    required this.backendService,
  });

  final ShogiExtendBackendService backendService;

  @override
  State<ShogiExtendBackendSettingsSheet> createState() => _ShogiExtendBackendSettingsSheetState();
}

class _ShogiExtendBackendSettingsSheetState extends State<ShogiExtendBackendSettingsSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _errorMessage;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final current = await widget.backendService.baseUrl;
    if (!mounted) {
      return;
    }
    _controller.text = current;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final normalized = widget.backendService.normalizeBaseUrl(_controller.text);
    if (normalized == null) {
      setState(() {
        _errorMessage = 'http または https の有効な URL を入力してください';
      });
      return;
    }
    await widget.backendService.saveBaseUrl(normalized);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _healthCheck() async {
    setState(() {
      _isTesting = true;
      _errorMessage = null;
    });
    final normalized = widget.backendService.normalizeBaseUrl(_controller.text);
    if (normalized == null) {
      setState(() {
        _isTesting = false;
        _errorMessage = 'http または https の有効な URL を入力してください';
      });
      return;
    }
    await widget.backendService.saveBaseUrl(normalized);
    final ok = await widget.backendService.healthCheck();
    if (!mounted) {
      return;
    }
    setState(() {
      _isTesting = false;
      _errorMessage = ok ? null : 'backend に接続できませんでした';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'backend 接続成功' : 'backend 接続失敗')),
    );
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
                            'backend 設定',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppPalette.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '将棋ウォーズ username 同期で使う backend の base URL を設定します。',
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
                  controller: _controller,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() {
                        _errorMessage = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: BackendSettingsStore.defaultBaseUrl,
                    filled: true,
                    fillColor: AppPalette.surface,
                    errorText: _errorMessage,
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isTesting ? null : _healthCheck,
                        icon: _isTesting
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
                        onPressed: _save,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
