import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/shogi_models.dart';
import '../../services/kifu_storage_service.dart';
import '../../services/kifu_parser.dart';
import '../../services/url_source_store.dart';
import '../../shared/theme/app_palette.dart';
import '../game/presentation/game_page.dart';
import '../game/presentation/game_setup_sheet.dart';
import 'saved_kif_list_sheet.dart';
import 'url_registration_sheet.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static final KifuStorageService _kifuStorageService = KifuStorageService();
  static final URLSourceStore _urlSourceStore = URLSourceStore();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppPalette.bgTop, AppPalette.bgBottom, Color(0xFFFDF7FB)],
          ),
        ),
        child: Stack(
          children: [
            const _AmbientCircle(
              color: Color(0x14D12E78),
              size: 280,
              offset: Offset(-150, -300),
            ),
            const _AmbientCircle(
              color: Color(0x12DB8566),
              size: 250,
              offset: Offset(165, -210),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeroCard(theme: theme),
                        const SizedBox(height: 24),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 330),
                          child: Column(
                            children: [
                              _StartActionButton(
                                icon: Icons.play_arrow_rounded,
                                label: '対局',
                                isProminent: true,
                                onPressed: () => _showGameSetupSheet(context, ref),
                              ),
                              const SizedBox(height: 12),
                              _StartActionButton(
                                icon: Icons.menu_book_rounded,
                                label: '棋譜',
                                onPressed: () => _showSavedKifSheet(context, ref),
                              ),
                              const SizedBox(height: 12),
                              _StartActionButton(
                                icon: Icons.link_rounded,
                                label: 'URL登録',
                                onPressed: () => _showUrlRegistrationSheet(context),
                              ),
                              const SizedBox(height: 12),
                              _StartActionButton(
                                icon: Icons.timer_outlined,
                                label: 'タイマー',
                                onPressed: () => _showPendingSheet(
                                  context,
                                  title: 'タイマー',
                                  message: '独立タイマー画面と設定シートは未実装です。',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'サクッと対局、あとからじっくり検討',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppPalette.neutral,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showGameSetupSheet(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<GameLaunchConfiguration>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.92,
        child: GameSetupSheet(),
      ),
    );

    if (!context.mounted || result == null) {
      return;
    }

    ref.read(gameSessionProvider.notifier).resetSession(handicap: result.handicap);
    ref.read(gameSessionProvider.notifier).setFlags(
      showStartScreen: false,
      showGameEndPopup: false,
      isReviewMode: false,
      showMatchStartCue: true,
    );
    ref.read(gameSessionProvider.notifier).setStatusMessage('先手の初手を待っています');
    ref.read(clockControllerProvider.notifier).resetClocks(
      sente: result.senteSeconds,
      gote: result.goteSeconds,
      byoYomi: result.byoYomiSeconds,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const GamePage(),
      ),
    );
  }

  Future<void> _showPendingSheet(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFF7EA),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(message, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSavedKifSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.84,
          child: SavedKifListSheet(
            storageService: _kifuStorageService,
            urlSourceStore: _urlSourceStore,
            onOpen: (entry) async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final record = await _kifuStorageService.loadRecord(entry.file);
                ref.read(gameSessionProvider.notifier).openPersistedRecordForReview(record);
                if (context.mounted) {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GamePage(),
                    ),
                  );
                }
              } on KifuParseException catch (error) {
                messenger.showSnackBar(
                  SnackBar(content: Text('棋譜の読込に失敗しました: ${error.message}')),
                );
              } catch (error) {
                messenger.showSnackBar(
                  SnackBar(content: Text('棋譜の読込に失敗しました: $error')),
                );
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _showUrlRegistrationSheet(BuildContext context) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => URLRegistrationSheet(urlSourceStore: _urlSourceStore),
    );
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL を登録しました')),
      );
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [AppPalette.cardBg, Color(0x14D12E78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x38D12E78), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14D12E78),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x14D12E78),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 14, color: AppPalette.info),
                      SizedBox(width: 6),
                      Text(
                        'WELCOME',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.info,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Hanafubuki',
                  style: TextStyle(
                    fontFamily: 'Times New Roman',
                    fontSize: 17,
                    letterSpacing: 1,
                    color: AppPalette.review,
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppPalette.info, AppPalette.warning],
                  ).createShader(bounds),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '87',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Times New Roman',
                          fontSize: 60,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 2),
                      Text(
                        '吹棋',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '持ち駒を打って王を詰ませよう',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppPalette.neutral,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PieceBadge(symbol: '王', owner: ShogiPlayer.gote),
                    SizedBox(width: 18),
                    _PieceBadge(symbol: '飛', owner: ShogiPlayer.sente),
                    SizedBox(width: 18),
                    _PieceBadge(symbol: '角', owner: ShogiPlayer.gote),
                  ],
                ),
                const SizedBox(height: 16),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FeatureTag(text: 'すぐ対局', icon: Icons.bolt_rounded),
                    _FeatureTag(text: '検討対応', icon: Icons.compare_arrows_rounded),
                    _FeatureTag(text: 'KIF保存', icon: Icons.download_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StartActionButton extends StatelessWidget {
  const _StartActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isProminent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isProminent;

  @override
  Widget build(BuildContext context) {
    final foreground = isProminent ? Colors.white : AppPalette.info;
    return SizedBox(
      width: double.infinity,
      height: isProminent ? 60 : 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          elevation: isProminent ? 2 : 0,
          backgroundColor: isProminent ? AppPalette.info : AppPalette.cardBg,
          foregroundColor: foreground,
          side: isProminent ? null : const BorderSide(color: Color(0x38D12E78)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: TextStyle(
            fontSize: isProminent ? 20 : 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PieceBadge extends StatelessWidget {
  const _PieceBadge({required this.symbol, required this.owner});

  final String symbol;
  final ShogiPlayer owner;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xD9FFFFFF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x3DD12E78)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14D12E78),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: RotatedBox(
          quarterTurns: owner == ShogiPlayer.gote ? 2 : 0,
          child: Container(
            width: 36,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF7E3B8), Color(0xFFE4BA77)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF7F5A2A), width: 1.4),
            ),
            child: Center(
              child: Text(
                symbol,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3A2410),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureTag extends StatelessWidget {
  const _FeatureTag({required this.text, required this.icon});

  final String text;
  final IconData icon;


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x14D12E78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x38D12E78)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppPalette.info),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppPalette.info,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientCircle extends StatelessWidget {
  const _AmbientCircle({
    required this.color,
    required this.size,
    required this.offset,
  });

  final Color color;
  final double size;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}