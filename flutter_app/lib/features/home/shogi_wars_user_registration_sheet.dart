import 'package:flutter/material.dart';

import '../../services/shogi_wars_user_store.dart';
import '../../shared/theme/app_palette.dart';

class ShogiWarsUserRegistrationSheet extends StatefulWidget {
  const ShogiWarsUserRegistrationSheet({
    super.key,
    required this.onRegister,
  });

  final Future<ShogiWarsUserAddResult> Function(String username) onRegister;

  @override
  State<ShogiWarsUserRegistrationSheet> createState() => _ShogiWarsUserRegistrationSheetState();
}

class _ShogiWarsUserRegistrationSheetState extends State<ShogiWarsUserRegistrationSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _errorMessage;
  bool _isRegistering = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });
    final result = await widget.onRegister(_controller.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _isRegistering = false;
    });
    if (result.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _errorMessage = switch (result) {
        ShogiWarsUserAddResult.empty => 'ユーザー名を入力してください',
        ShogiWarsUserAddResult.invalidUsername => '英数字、アンダースコア、ハイフンのみ使えます',
        ShogiWarsUserAddResult.duplicate => 'このユーザーはすでに登録済みです',
        ShogiWarsUserAddResult.backendUnavailable => 'backend に接続できませんでした',
        ShogiWarsUserAddResult.added => null,
      };
    });
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
                            'ユーザー登録',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppPalette.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '登録した username は backend へスクレイプ要求を送ります。',
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
                  autocorrect: false,
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() {
                        _errorMessage = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'chubby_cat',
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isRegistering ? null : _register,
                    icon: _isRegistering
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.person_add_alt_rounded),
                    label: Text(_isRegistering ? '登録中...' : '登録'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
