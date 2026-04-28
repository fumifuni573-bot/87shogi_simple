import 'package:flutter/material.dart';

import '../../../domain/models/shogi_models.dart';
import '../../../shared/theme/app_palette.dart';

class GameLaunchConfiguration {
  const GameLaunchConfiguration({
    required this.handicap,
    required this.senteSeconds,
    required this.goteSeconds,
    required this.byoYomiSeconds,
  });

  final GameHandicap handicap;
  final double senteSeconds;
  final double goteSeconds;
  final int byoYomiSeconds;
}

class GameSetupSheet extends StatefulWidget {
  const GameSetupSheet({super.key});

  @override
  State<GameSetupSheet> createState() => _GameSetupSheetState();
}

class _GameSetupSheetState extends State<GameSetupSheet> {
  static const List<_ClockPreset> _clockPresets = [
    _ClockPreset(label: '10分', mainSeconds: 600, byoYomiSeconds: 0),
    _ClockPreset(label: '5分+30秒', mainSeconds: 300, byoYomiSeconds: 30),
    _ClockPreset(label: '3分+10秒', mainSeconds: 180, byoYomiSeconds: 10),
    _ClockPreset(label: '秒読み60秒', mainSeconds: 0, byoYomiSeconds: 60),
  ];

  GameHandicap _selectedHandicap = GameHandicap.none;
  _ClockPreset _selectedClock = _clockPresets.first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.cardBg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: AppPalette.shadow,
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppPalette.info,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'GAME SETUP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '対局設定',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: AppPalette.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '駒落ちを選択して対局を開始できます',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppPalette.neutral,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '手合割',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppPalette.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: GameHandicap.values
                                  .map(
                                    (handicap) => _SelectionChip(
                                      label: _handicapLabel(handicap),
                                      selected: handicap == _selectedHandicap,
                                      onTap: () {
                                        setState(() {
                                          _selectedHandicap = handicap;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '持ち時間',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppPalette.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._clockPresets.map(
                              (preset) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ClockPresetTile(
                                  preset: preset,
                                  selected: preset == _selectedClock,
                                  onTap: () {
                                    setState(() {
                                      _selectedClock = preset;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.info,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(
                              GameLaunchConfiguration(
                                handicap: _selectedHandicap,
                                senteSeconds: _selectedClock.mainSeconds.toDouble(),
                                goteSeconds: _selectedClock.mainSeconds.toDouble(),
                                byoYomiSeconds: _selectedClock.byoYomiSeconds,
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text(
                            'この設定で対局開始',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
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
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppPalette.info : AppPalette.cardBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppPalette.info : AppPalette.warning.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppPalette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockPresetTile extends StatelessWidget {
  const _ClockPresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final _ClockPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppPalette.info.withValues(alpha: 0.08) : AppPalette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppPalette.info : AppPalette.warning.withValues(alpha: 0.3),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.label,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preset.detail,
                      style: TextStyle(
                        color: AppPalette.neutral,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? AppPalette.info : AppPalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClockPreset {
  const _ClockPreset({
    required this.label,
    required this.mainSeconds,
    required this.byoYomiSeconds,
  });

  final String label;
  final int mainSeconds;
  final int byoYomiSeconds;

  String get detail {
    if (mainSeconds == 0) {
      return '持ち時間なし / 秒読み $byoYomiSeconds 秒';
    }
    if (byoYomiSeconds == 0) {
      return '先手後手ともに ${mainSeconds ~/ 60} 分';
    }
    return '先手後手ともに ${mainSeconds ~/ 60} 分 / 秒読み $byoYomiSeconds 秒';
  }
}