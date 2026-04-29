import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/models/shogi_models.dart';
import '../../../services/kifu_storage_service.dart';
import '../../../services/shogi_extend_backend_service.dart';
import '../../../services/shogi_wars_user_store.dart';
import '../../../services/url_source_store.dart';
import '../state/game_session_controller.dart';
import '../../../logic/clock_logic.dart';
import '../../../shared/theme/app_palette.dart';
import '../../home/saved_kif_list_sheet.dart';

class GamePage extends ConsumerStatefulWidget {
  const GamePage({super.key});

  @override
  ConsumerState<GamePage> createState() => _GamePageState();
}

class _GamePageState extends ConsumerState<GamePage> {
  Timer? _startCueTimer;
  final KifuStorageService _kifuStorageService = KifuStorageService();
  final URLSourceStore _urlSourceStore = URLSourceStore();
  final ShogiWarsUserStore _shogiWarsUserStore = ShogiWarsUserStore();
  final ShogiExtendBackendService _backendService = ShogiExtendBackendService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleMatchStartCueDismissal();
    });
  }

  @override
  void dispose() {
    _startCueTimer?.cancel();
    super.dispose();
  }

  void _scheduleMatchStartCueDismissal() {
    final session = ref.read(gameSessionProvider);
    if (!session.showMatchStartCue) {
      return;
    }

    _startCueTimer?.cancel();
    _startCueTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) {
        return;
      }
      ref.read(gameSessionProvider.notifier).dismissMatchStartCue();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameSessionProvider);
    final clock = ref.watch(clockControllerProvider);
    final controller = ref.read(gameSessionProvider.notifier);
    final legalTargets = controller.currentLegalTargets();

    if (session.showMatchStartCue && (_startCueTimer == null || !_startCueTimer!.isActive)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scheduleMatchStartCueDismissal();
        }
      });
    }

    return Scaffold(
      backgroundColor: AppPalette.bgBottom,
      body: Stack(
        children: [
          Positioned.fill(
            child: _SakuraPetalBackground(
              opacity: session.isReviewMode ? 0.22 : 0.28,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = math.max(260.0, constraints.maxWidth - 8);
                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(8, 46, 8, 4),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 50),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CompactStatusStrip(
                              turn: session.turn,
                              handicapLabel: _handicapLabel(session.selectedHandicap),
                              statusMessage: session.statusMessage,
                              latestMove: session.moveRecords.isNotEmpty ? session.moveRecords.last : null,
                            ),
                            const SizedBox(height: 6),
                            AnimatedOpacity(
                              opacity: session.isReviewMode ? 0 : 1,
                              duration: const Duration(milliseconds: 180),
                              child: IgnorePointer(
                                ignoring: session.isReviewMode,
                                child: _PlayerControlStrip(
                                  label: '後手',
                                  remaining: clock.goteClockRemaining,
                                  byoYomiRemaining: clock.goteByoYomiRemaining,
                                  isActive: clock.timerActivePlayer == ShogiPlayer.gote,
                                  isTopPlayer: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _CompactHandTray(
                              title: '後手の持ち駒',
                              owner: ShogiPlayer.gote,
                              activePlayer: session.turn,
                              pieces: session.goteHand,
                              selectedDropType: session.selectedDropType,
                              onPieceTap: controller.toggleDropSelection,
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: boardSize,
                              height: boardSize,
                              child: _BoardPanel(
                                board: session.board,
                                selected: session.selected,
                                legalTargets: legalTargets,
                                onSquareTap: (square) => controller.handleBoardTap(square),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _CompactHandTray(
                              title: '先手の持ち駒',
                              owner: ShogiPlayer.sente,
                              activePlayer: session.turn,
                              pieces: session.senteHand,
                              selectedDropType: session.selectedDropType,
                              onPieceTap: controller.toggleDropSelection,
                            ),
                            const SizedBox(height: 4),
                            if (session.isReviewMode)
                              _ReviewControlPanel(
                                currentIndex: session.reviewIndex,
                                maxIndex: controller.reviewMaxIndex(),
                                onStart: controller.goToReviewStart,
                                onBack: () => controller.moveReviewBy(-1),
                                onForward: () => controller.moveReviewBy(1),
                                onEnd: controller.goToReviewEnd,
                                onScrub: controller.seekReview,
                                onResume: controller.resumeFromReview,
                              )
                            else
                              _PlayerControlStrip(
                                label: '先手',
                                remaining: clock.senteClockRemaining,
                                byoYomiRemaining: clock.senteByoYomiRemaining,
                                isActive: clock.timerActivePlayer == ShogiPlayer.sente,
                                isTopPlayer: false,
                              ),
                          ],
                        ),
                    ),
                  ),
                    Positioned(
                      top: 2,
                      left: 8,
                      child: _TopActionButtons(
                        showKifButton: session.isReviewMode,
                        onHome: _confirmReturnHome,
                        onKif: _showSavedKifSheet,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (session.showMatchStartCue)
            _MatchStartOverlay(
              topRole: _matchStartTopRole(session),
              bottomRole: _matchStartBottomRole(session),
            ),
          if (session.showGameEndPopup)
            _GameEndOverlay(
              title: _gameEndTitle(session),
              message: _gameEndMessage(session),
              onReview: controller.enterReviewMode,
              onSaveKif: () => _saveKif(controller),
              onExportKif: () => _exportKif(controller),
              onRematch: () {
                controller.resetSession(handicap: session.selectedHandicap);
                controller.setFlags(showStartScreen: false, showMatchStartCue: true);
                _scheduleMatchStartCueDismissal();
              },
              onHome: () {
                controller.returnToStartScreen();
                Navigator.of(context).pop();
              },
              onClose: controller.dismissGameEndPopup,
            ),
        ],
      ),
    ).maybePopPromotionDialog(context, session, controller);
  }

  String _matchStartTopRole(GameSessionState session) {
    return (session.selectedHandicap == GameHandicap.none && session.turn == ShogiPlayer.gote) ? '先手' : '後手';
  }

  String _matchStartBottomRole(GameSessionState session) {
    return _matchStartTopRole(session) == '先手' ? '後手' : '先手';
  }

  String _gameEndTitle(GameSessionState session) {
    if (session.winner case final winner?) {
      return winner == ShogiPlayer.sente ? '先手勝利' : '後手勝利';
    }
    if (session.isSennichite) {
      return '引き分け';
    }
    if (session.isInterrupted) {
      return '対局中断';
    }
    return '対局終了';
  }

  String _gameEndMessage(GameSessionState session) {
    if (session.winner case final winner?) {
      return '${winner.label}の勝ち（${session.winReason}）';
    }
    if (session.isSennichite) {
      return '千日手（引き分け）';
    }
    if (session.isInterrupted) {
      return '対局中断';
    }
    return '';
  }

  String _handicapLabel(GameHandicap handicap) {
    switch (handicap) {
      case GameHandicap.none:
        return '平手';
      case GameHandicap.lance:
        return '香落ち';
      case GameHandicap.bishop:
        return '角落ち';
      case GameHandicap.rook:
        return '飛車落ち';
      case GameHandicap.twoPieces:
        return '二枚落ち';
      case GameHandicap.fourPieces:
        return '四枚落ち';
      case GameHandicap.sixPieces:
        return '六枚落ち';
    }
  }

  Future<void> _saveKif(GameSessionController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await _kifuStorageService.saveToLibrary(controller.buildPersistedRecord());
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('KIFを保存しました: ${file.path}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('KIF保存に失敗しました: $error')),
      );
    }
  }

  Future<void> _exportKif(GameSessionController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await _kifuStorageService.exportAndShare(controller.buildPersistedRecord());
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('KIFを出力しました: ${file.path}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('KIF出力に失敗しました: $error')),
      );
    }
  }

  Future<void> _confirmReturnHome() async {
    final session = ref.read(gameSessionProvider);
    final controller = ref.read(gameSessionProvider.notifier);
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(session.isReviewMode ? '検討を終了しますか？' : '対局を終了しますか？'),
        content: Text(
          session.isReviewMode ? '検討モードを終了してホーム画面に戻ります。' : '進行中の対局を終了してホーム画面に戻ります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('終了する'),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      controller.returnToStartScreen();
      Navigator.of(context).pop();
    }
  }

  Future<void> _showSavedKifSheet() async {
    final controller = ref.read(gameSessionProvider.notifier);
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
            userStore: _shogiWarsUserStore,
            backendService: _backendService,
            onOpen: (entry) async {
              final record = await _kifuStorageService.loadRecord(entry.file);
              controller.openPersistedRecordForReview(record);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        );
      },
    );
  }
}

class _TopActionButtons extends StatelessWidget {
  const _TopActionButtons({
    required this.showKifButton,
    required this.onHome,
    required this.onKif,
  });

  final bool showKifButton;
  final VoidCallback onHome;
  final VoidCallback onKif;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TopActionButton(
          icon: Icons.home_rounded,
          onPressed: onHome,
        ),
        if (showKifButton) ...[
          const SizedBox(width: 8),
          _TopActionButton(
            icon: Icons.library_books_rounded,
            onPressed: onKif,
          ),
        ],
      ],
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: Colors.white.withValues(alpha: 0.72),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, size: 18, color: AppPalette.info),
        ),
      ),
    );
  }
}

class _CompactStatusStrip extends StatelessWidget {
  const _CompactStatusStrip({
    required this.turn,
    required this.handicapLabel,
    required this.statusMessage,
    this.latestMove,
  });

  final ShogiPlayer turn;
  final String handicapLabel;
  final String statusMessage;
  final String? latestMove;

  @override
  Widget build(BuildContext context) {
    final turnLabel = turn == ShogiPlayer.sente ? '先手番' : '後手番';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SmallBadge(label: turnLabel),
              const SizedBox(width: 6),
              _SmallBadge(label: handicapLabel),
              if (latestMove != null) ...[
                const Spacer(),
                Flexible(
                  child: Text(
                    latestMove!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppPalette.info,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PlayerControlStrip extends StatelessWidget {
  const _PlayerControlStrip({
    required this.label,
    required this.remaining,
    required this.byoYomiRemaining,
    required this.isActive,
    required this.isTopPlayer,
  });

  final String label;
  final double remaining;
  final double byoYomiRemaining;
  final bool isActive;
  final bool isTopPlayer;

  @override
  Widget build(BuildContext context) {
    final displaySeconds = ClockLogic.displaySeconds(
      main: remaining,
      byoYomiRemaining: byoYomiRemaining,
      byoYomiSeconds: byoYomiRemaining > 0 ? byoYomiRemaining.ceil() : 0,
    );
    final panel = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isActive ? 0.88 : 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppPalette.info.withValues(alpha: 0.7) : AppPalette.outline,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (isActive) ...[
                  const Text(
                    '▶',
                    style: TextStyle(
                      color: AppPalette.info,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? AppPalette.info : AppPalette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _formatClock(displaySeconds),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? AppPalette.info : AppPalette.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            byoYomiRemaining > 0 ? '秒読み ${_formatClock(byoYomiRemaining)}' : '秒読みなし',
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return isTopPlayer ? RotatedBox(quarterTurns: 2, child: panel) : panel;
  }

  String _formatClock(double seconds) {
    final totalSeconds = seconds.ceil();
    final minutes = totalSeconds ~/ 60;
    final remainSeconds = totalSeconds % 60;
    return '$minutes:${remainSeconds.toString().padLeft(2, '0')}';
  }
}

class _CompactHandTray extends StatelessWidget {
  const _CompactHandTray({
    required this.title,
    required this.owner,
    required this.activePlayer,
    required this.pieces,
    required this.selectedDropType,
    required this.onPieceTap,
  });

  final String title;
  final ShogiPlayer owner;
  final ShogiPlayer activePlayer;
  final Map<ShogiPieceType, int> pieces;
  final ShogiPieceType? selectedDropType;
  final ValueChanged<ShogiPieceType> onPieceTap;

  @override
  Widget build(BuildContext context) {
    final isActiveTray = owner == activePlayer;
    final orderedTypes = ShogiPieceType.handOrder;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              title,
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemSide = ((constraints.maxWidth - 6 * 4) / 7).clamp(40.0, 54.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: orderedTypes.map((type) {
                    final count = pieces[type] ?? 0;
                    final isSelected = isActiveTray && selectedDropType == type;
                    return _CompactHandPieceSlot(
                      type: type,
                      count: count,
                      owner: owner,
                      itemSide: itemSide,
                      isSelected: isSelected,
                      isEnabled: isActiveTray && count > 0,
                      onTap: () => onPieceTap(type),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactHandPieceSlot extends StatelessWidget {
  const _CompactHandPieceSlot({
    required this.type,
    required this.count,
    required this.owner,
    required this.itemSide,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final ShogiPieceType type;
  final int count;
  final ShogiPlayer owner;
  final double itemSide;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = count > 0
        ? (isSelected ? AppPalette.info.withValues(alpha: 0.26) : AppPalette.info.withValues(alpha: 0.10))
        : Colors.grey.withValues(alpha: 0.10);
    final borderColor = isSelected
        ? AppPalette.info
        : (count > 0 ? AppPalette.info.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.12));
    final pieceFrame = itemSide * 0.80;
    final komaWidth = math.max(20.0, itemSide * 0.48);
    final komaHeight = math.max(24.0, itemSide * 0.58);
    final fontSize = math.max(10.0, itemSide * 0.25);

    return SizedBox(
      width: itemSide,
      height: itemSide,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: isEnabled ? onTap : null,
          child: Ink(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: pieceFrame,
                      height: pieceFrame,
                      decoration: BoxDecoration(
                        color: count > 0
                            ? AppPalette.neutral.withValues(alpha: 0.10)
                            : Colors.grey.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: count > 0
                              ? Colors.black.withValues(alpha: isSelected ? 0.16 : 0.10)
                              : Colors.grey.withValues(alpha: 0.20),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: ColorFiltered(
                          colorFilter: count > 0
                              ? const ColorFilter.mode(Colors.transparent, BlendMode.srcOver)
                              : const ColorFilter.matrix(<double>[
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0, 0, 0, 1, 0,
                                ]),
                          child: _BoardPieceGlyph(
                            symbol: type.symbol,
                            owner: owner,
                            width: komaWidth,
                            height: komaHeight,
                            fontSize: fontSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (count > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      size: 11,
                      color: isSelected ? AppPalette.info : AppPalette.textMuted.withValues(alpha: 0.55),
                    ),
                  ),
                if (count > 0)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _BoardPanel extends StatelessWidget {
  const _BoardPanel({
    required this.board,
    required this.selected,
    required this.legalTargets,
    required this.onSquareTap,
  });

  final List<List<ShogiPiece?>> board;
  final BoardSquare? selected;
  final List<BoardSquare> legalTargets;
  final ValueChanged<BoardSquare> onSquareTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppPalette.boardFrame,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: AppPalette.modalShadow,
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 81,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
          ),
          itemBuilder: (context, index) {
            final row = index ~/ 9;
            final column = index % 9;
            final piece = board[row][column];
            final square = BoardSquare(row: row, col: column);
            final isSelected = selected != null && selected!.row == row && selected!.col == column;
            final isLegalTarget = legalTargets.any((target) => target.row == row && target.col == column);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSquareTap(square),
                child: Ink(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppPalette.boardFrame, width: 0.6),
                    color: isSelected
                        ? AppPalette.boardSelected
                        : isLegalTarget
                            ? AppPalette.boardTarget
                            : ((row + column).isEven ? AppPalette.boardLight : AppPalette.boardDark),
                  ),
                  child: Stack(
                    children: [
                      if (isLegalTarget)
                        const Center(
                          child: SizedBox(
                            width: 10,
                            height: 10,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppPalette.boardTargetMarker,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      Center(
                        child: piece == null
                            ? null
                            : _BoardPieceGlyph(
                                symbol: piece.displaySymbol,
                                owner: piece.owner,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BoardPieceGlyph extends StatelessWidget {
  const _BoardPieceGlyph({
    required this.symbol,
    this.owner = ShogiPlayer.sente,
    this.width = 29,
    this.height = 34,
    this.fontSize = 16,
  });

  final String symbol;
  final ShogiPlayer owner;
  final double width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: RotatedBox(
        quarterTurns: owner == ShogiPlayer.gote ? 2 : 0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipPath(
              clipper: const _KomaShapeClipper(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppPalette.pieceFillTop, AppPalette.pieceFillBottom],
                  ),
                ),
              ),
            ),
            CustomPaint(
              size: Size(width, height),
              painter: const _KomaBorderPainter(),
            ),
            Text(
              symbol,
              style: TextStyle(
                color: AppPalette.pieceText,
                fontWeight: FontWeight.w900,
                fontSize: fontSize,
                shadows: const [
                  Shadow(
                    color: AppPalette.pieceShadow,
                    blurRadius: 0.5,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SakuraPetalBackground extends StatefulWidget {
  const _SakuraPetalBackground({required this.opacity});

  final double opacity;

  @override
  State<_SakuraPetalBackground> createState() => _SakuraPetalBackgroundState();
}

class _SakuraPetalBackgroundState extends State<_SakuraPetalBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final area = constraints.maxWidth * constraints.maxHeight;
            final baseCount = (area / 25000).round().clamp(24, 56);
            final backLayerCount = (baseCount * 0.58).round();
            final frontLayerCount = (baseCount * 0.42).round();

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final phase = _controller.value;
                return Opacity(
                  opacity: widget.opacity,
                  child: Stack(
                    children: [
                      _SakuraPetalLayer(
                        phase: phase,
                        petalCount: backLayerCount,
                        canvasSize: constraints.biggest,
                        baseSalt: 0,
                        minWidth: 8,
                        widthDelta: 6,
                        minDrift: 10,
                        driftDelta: 12,
                        minSpeed: 0.14,
                        speedDelta: 0.18,
                        opacityScale: 0.72,
                      ),
                      _SakuraPetalLayer(
                        phase: phase,
                        petalCount: frontLayerCount,
                        canvasSize: constraints.biggest,
                        baseSalt: 100,
                        minWidth: 12,
                        widthDelta: 8,
                        minDrift: 14,
                        driftDelta: 18,
                        minSpeed: 0.20,
                        speedDelta: 0.24,
                        opacityScale: 1,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SakuraPetalLayer extends StatelessWidget {
  const _SakuraPetalLayer({
    required this.phase,
    required this.petalCount,
    required this.canvasSize,
    required this.baseSalt,
    required this.minWidth,
    required this.widthDelta,
    required this.minDrift,
    required this.driftDelta,
    required this.minSpeed,
    required this.speedDelta,
    required this.opacityScale,
  });

  final double phase;
  final int petalCount;
  final Size canvasSize;
  final int baseSalt;
  final double minWidth;
  final double widthDelta;
  final double minDrift;
  final double driftDelta;
  final double minSpeed;
  final double speedDelta;
  final double opacityScale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(petalCount, (index) {
        final saltedIndex = index + baseSalt;
        final width = minWidth + _seeded(saltedIndex, 10.3) * widthDelta;
        final height = width * (1.25 + _seeded(saltedIndex, 11.7) * 0.5);
        final speed = minSpeed + _seeded(saltedIndex, 12.9) * speedDelta;
        final offsetX = _seeded(saltedIndex, 21.1) * canvasSize.width;
        final loopY = (phase * speed + _seeded(saltedIndex, 22.7)) % 1.25;
        final y = (loopY - 0.15) * canvasSize.height;
        final drift = math.sin(
              (phase * math.pi * 2.0) + _seeded(saltedIndex, 31.4) * math.pi * 2.0,
            ) *
            (minDrift + _seeded(saltedIndex, 34.8) * driftDelta);
        final rotation = ((phase * 360 * (0.30 + _seeded(saltedIndex, 15.4))) +
                _seeded(saltedIndex, 9.2) * 360) *
            math.pi /
            180;

        return Positioned(
          left: offsetX + drift,
          top: y,
          child: Transform.rotate(
            angle: rotation,
            child: Opacity(
              opacity: (0.52 + _seeded(saltedIndex, 5.8) * 0.30) * opacityScale,
              child: Container(
                width: width,
                height: height,
                decoration: const ShapeDecoration(
                  shape: _SakuraPetalShape(),
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF2CCE0),
                      Color(0xFFD999CC),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shadows: [
                    BoxShadow(
                      color: Color(0x40D9B3D9),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  double _seeded(int index, double salt) {
    final raw = math.sin(index * 12.9898 + salt) * 43758.5453123;
    return raw - raw.floorToDouble();
  }
}

class _SakuraPetalShape extends ShapeBorder {
  const _SakuraPetalShape();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    final width = rect.width;
    final height = rect.height;

    path.moveTo(rect.left + width * 0.5, rect.top);
    path.cubicTo(
      rect.left + width * 0.87,
      rect.top + height * 0.08,
      rect.left + width * 1.02,
      rect.top + height * 0.34,
      rect.left + width,
      rect.top + height * 0.55,
    );
    path.cubicTo(
      rect.left + width * 0.95,
      rect.top + height * 0.90,
      rect.left + width * 0.70,
      rect.top + height,
      rect.left + width * 0.5,
      rect.top + height,
    );
    path.cubicTo(
      rect.left + width * 0.30,
      rect.top + height,
      rect.left + width * 0.05,
      rect.top + height * 0.90,
      rect.left,
      rect.top + height * 0.55,
    );
    path.cubicTo(
      rect.left - width * 0.02,
      rect.top + height * 0.34,
      rect.left + width * 0.13,
      rect.top + height * 0.08,
      rect.left + width * 0.5,
      rect.top,
    );

    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

class _KomaShapeClipper extends CustomClipper<Path> {
  const _KomaShapeClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    final topY = size.height * 0.02;
    final shoulderY = size.height * 0.17;

    path.moveTo(size.width / 2, topY);
    path.lineTo(size.width - size.width * 0.16, shoulderY);
    path.lineTo(size.width - size.width * 0.03, size.height - size.height * 0.02);
    path.lineTo(size.width * 0.03, size.height - size.height * 0.02);
    path.lineTo(size.width * 0.16, shoulderY);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _KomaBorderPainter extends CustomPainter {
  const _KomaBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = AppPalette.pieceBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(const _KomaShapeClipper().getClip(size), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension on Widget {
  Widget maybePopPromotionDialog(
    BuildContext context,
    GameSessionState session,
    GameSessionController controller,
  ) {
    if (session.pendingPromotionMove != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) {
          return;
        }
        final promote = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('成りますか？'),
            content: const Text('この駒は成ることができます'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('戻る'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('成らない'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('成る'),
              ),
            ],
          ),
        );

        if (promote == null) {
          controller.cancelPendingPromotion();
        } else {
          controller.resolvePendingPromotion(promote: promote);
        }
      });
    }

    return this;
  }
}

class _MatchStartOverlay extends StatelessWidget {
  const _MatchStartOverlay({
    required this.topRole,
    required this.bottomRole,
  });

  final String topRole;
  final String bottomRole;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: AppPalette.overlay,
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          decoration: BoxDecoration(
            color: AppPalette.turnSente.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x66FFFFFF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotatedBox(
                quarterTurns: 2,
                child: Text(
                  topRole,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                '対局開始',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                bottomRole,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameEndOverlay extends StatelessWidget {
  const _GameEndOverlay({
    required this.title,
    required this.message,
    required this.onReview,
    required this.onSaveKif,
    required this.onExportKif,
    required this.onRematch,
    required this.onHome,
    required this.onClose,
  });

  final String title;
  final String message;
  final VoidCallback onReview;
  final VoidCallback onSaveKif;
  final VoidCallback onExportKif;
  final VoidCallback onRematch;
  final VoidCallback onHome;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppPalette.overlayStrong,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppPalette.cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: AppPalette.modalShadow,
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppPalette.info,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: const Text('検討'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSaveKif,
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text('KIF保存'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onExportKif,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('KIF出力'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRematch,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('再対局'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onHome,
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('ホームに戻る'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onClose,
                child: const Text('閉じる'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewControlPanel extends StatelessWidget {
  const _ReviewControlPanel({
    required this.currentIndex,
    required this.maxIndex,
    required this.onStart,
    required this.onBack,
    required this.onForward,
    required this.onEnd,
    required this.onScrub,
    required this.onResume,
  });

  final int currentIndex;
  final int maxIndex;
  final VoidCallback onStart;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onEnd;
  final ValueChanged<int> onScrub;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final isAtStart = currentIndex == 0;
    final isAtEnd = currentIndex >= maxIndex;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.review.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.review.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '検討モード',
            style: TextStyle(
              color: AppPalette.review,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Slider(
            value: currentIndex.toDouble(),
            min: 0,
            max: maxIndex > 0 ? maxIndex.toDouble() : 0,
            divisions: maxIndex > 0 ? maxIndex : null,
            onChanged: maxIndex > 0 ? (value) => onScrub(value.round()) : null,
          ),
          Row(
            children: [
              const Text('0手目'),
              const Spacer(),
              Text(
                '$currentIndex / $maxIndex',
                style: const TextStyle(
                  color: AppPalette.review,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text('$maxIndex手目'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isAtStart ? null : onStart,
                  child: const Icon(Icons.first_page_rounded),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: isAtStart ? null : onBack,
                  child: const Icon(Icons.chevron_left_rounded),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: isAtEnd ? null : onForward,
                  child: const Icon(Icons.chevron_right_rounded),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: isAtEnd ? null : onEnd,
                  child: const Icon(Icons.last_page_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text('この局面から再開'),
            ),
          ),
        ],
      ),
    );
  }
}