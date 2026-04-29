import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/models/shogi_models.dart';
import '../../../shared/theme/app_palette.dart';

class TimerPage extends ConsumerStatefulWidget {
  const TimerPage({super.key, this.showInitialSettingsSheet = true});

  final bool showInitialSettingsSheet;

  @override
  ConsumerState<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends ConsumerState<TimerPage> {
  static const _timerMinuteOptions = <int>[0, 1, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60];
  static const _byoYomiOptions = <int>[0, 10, 20, 30, 60];

  Timer? _ticker;
  double _standaloneSenteInitialSeconds = 600;
  double _standaloneGoteInitialSeconds = 600;
  int _standaloneByoYomiSeconds = 0;
  bool _didOpenInitialSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _applySettingsToClock();
      if (widget.showInitialSettingsSheet && !_didOpenInitialSettings) {
        _didOpenInitialSettings = true;
        unawaited(_openTimerSettingsSheet());
      }
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) {
        return;
      }
      ref.read(clockControllerProvider.notifier).tick(DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = ref.watch(clockControllerProvider);

    return Scaffold(
      backgroundColor: AppPalette.bgBottom,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppPalette.bgTop, AppPalette.bgBottom, Color(0xFFFDF7FB)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final centerControlHeight = math.max(120.0, constraints.maxHeight * 0.165);
              final panelSlotHeight = math.max(160.0, (constraints.maxHeight - centerControlHeight - 24) / 2);
              final panelSide = math.max(140.0, math.min(constraints.maxWidth - 10, panelSlotHeight));

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  children: [
                    SizedBox(
                      width: panelSide,
                      height: panelSide,
                      child: _TimerClockPanel(
                        playerName: 'Player 2',
                        remaining: ref.read(clockControllerProvider.notifier).displaySecondsFor(ShogiPlayer.gote),
                        isActive: clock.timerActivePlayer == ShogiPlayer.gote,
                        hasExpired: clock.timerExpiredPlayer == ShogiPlayer.gote,
                        isTopPanel: true,
                        rotationQuarterTurns: clock.timerRotationQuarterTurns,
                        onTap: () => ref.read(clockControllerProvider.notifier).handleStandaloneTap(ShogiPlayer.gote),
                        onLongPress: () => ref.read(clockControllerProvider.notifier).pauseTimer(),
                      ),
                    ),
                    SizedBox(
                      height: centerControlHeight,
                      child: _TimerCenterControls(
                        statusText: _timerStatusText(clock),
                        accent: AppPalette.info,
                        isDisabled: clock.isTimerRunning,
                        onHome: () => Navigator.of(context).pop(),
                        onReset: () => ref.read(clockControllerProvider.notifier).resetToInitialValues(),
                        onSettings: _openTimerSettingsSheet,
                        onRotate: () => ref.read(clockControllerProvider.notifier).setRotationQuarterTurns(
                              clock.timerRotationQuarterTurns + 1,
                            ),
                      ),
                    ),
                    SizedBox(
                      width: panelSide,
                      height: panelSide,
                      child: _TimerClockPanel(
                        playerName: 'Player 1',
                        remaining: ref.read(clockControllerProvider.notifier).displaySecondsFor(ShogiPlayer.sente),
                        isActive: clock.timerActivePlayer == ShogiPlayer.sente,
                        hasExpired: clock.timerExpiredPlayer == ShogiPlayer.sente,
                        isTopPanel: false,
                        rotationQuarterTurns: clock.timerRotationQuarterTurns,
                        onTap: () => ref.read(clockControllerProvider.notifier).handleStandaloneTap(ShogiPlayer.sente),
                        onLongPress: () => ref.read(clockControllerProvider.notifier).pauseTimer(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openTimerSettingsSheet() {
    if (ref.read(clockControllerProvider).isTimerRunning) {
      return Future<void>.value();
    }

    var senteMinutes = _currentMinutes(_standaloneSenteInitialSeconds);
    var goteMinutes = _currentMinutes(_standaloneGoteInitialSeconds);
    var byoYomiSeconds = _standaloneByoYomiSeconds;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'タイマー設定',
                                    style: TextStyle(
                                      color: AppPalette.textPrimary,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Player 1 / Player 2 の持ち時間と秒読みを設定します。',
                                    style: TextStyle(
                                      color: AppPalette.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
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
                        const SizedBox(height: 16),
                        _TimerSettingCard(
                          playerName: 'Player 2',
                          currentMinutes: goteMinutes,
                          timerMinuteOptions: _timerMinuteOptions,
                          timerMinuteLabel: _timerMinuteLabel,
                          onPickerChange: (value) => setModalState(() => goteMinutes = value),
                          onAdjust: (delta) => setModalState(() => goteMinutes = _clampMinute(goteMinutes + delta)),
                        ),
                        const SizedBox(height: 8),
                        _TimerSettingCard(
                          playerName: 'Player 1',
                          currentMinutes: senteMinutes,
                          timerMinuteOptions: _timerMinuteOptions,
                          timerMinuteLabel: _timerMinuteLabel,
                          onPickerChange: (value) => setModalState(() => senteMinutes = value),
                          onAdjust: (delta) => setModalState(() => senteMinutes = _clampMinute(senteMinutes + delta)),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppPalette.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppPalette.outline),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                '秒読み',
                                style: TextStyle(
                                  color: AppPalette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              DropdownButton<int>(
                                value: byoYomiSeconds,
                                underline: const SizedBox.shrink(),
                                items: _byoYomiOptions
                                    .map(
                                      (value) => DropdownMenuItem<int>(
                                        value: value,
                                        child: Text(value == 0 ? 'なし' : '$value秒'),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setModalState(() => byoYomiSeconds = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _standaloneSenteInitialSeconds = senteMinutes * 60.0;
                                _standaloneGoteInitialSeconds = goteMinutes * 60.0;
                                _standaloneByoYomiSeconds = byoYomiSeconds;
                              });
                              _applySettingsToClock();
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('設定を反映'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _applySettingsToClock() {
    ref.read(clockControllerProvider.notifier).resetClocks(
          sente: _standaloneSenteInitialSeconds,
          gote: _standaloneGoteInitialSeconds,
          byoYomi: _standaloneByoYomiSeconds,
        );
  }

  int _currentMinutes(double seconds) {
    return ((seconds / 60).round()).clamp(0, 60);
  }

  int _clampMinute(int minute) {
    return minute.clamp(0, 60);
  }

  String _timerMinuteLabel(int minute) {
    return minute == 0 ? 'なし' : '$minute分';
  }

  String _timerStatusText(dynamic clock) {
    if (clock.timerExpiredPlayer != null) {
      return clock.timerExpiredPlayer == ShogiPlayer.sente ? 'Player 1 の時間切れ' : 'Player 2 の時間切れ';
    }
    if (clock.timerActivePlayer != null && clock.isTimerRunning) {
      return clock.timerActivePlayer == ShogiPlayer.sente ? 'Player 1 の持ち時間' : 'Player 2 の持ち時間';
    }
    if (clock.timerActivePlayer != null) {
      return clock.timerActivePlayer == ShogiPlayer.sente ? '停止中（Player 1 の手番）' : '停止中（Player 2 の手番）';
    }
    return '開始ボタンまたは手番側をタップ';
  }
}

class _TimerClockPanel extends StatelessWidget {
  const _TimerClockPanel({
    required this.playerName,
    required this.remaining,
    required this.isActive,
    required this.hasExpired,
    required this.isTopPanel,
    required this.rotationQuarterTurns,
    required this.onTap,
    required this.onLongPress,
  });

  final String playerName;
  final double remaining;
  final bool isActive;
  final bool hasExpired;
  final bool isTopPanel;
  final int rotationQuarterTurns;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isSideways = rotationQuarterTurns % 2 != 0;
    final baseAngle = isSideways ? 0 : (isTopPanel ? 180 : 0);
    final panelFill = hasExpired
        ? const LinearGradient(colors: [AppPalette.danger, AppPalette.danger])
        : isActive
            ? const LinearGradient(
                colors: [Color(0xFFD12E78), Color(0xFFB31F66)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFE0C2D2), Color(0xFFCAA3B7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Transform.rotate(
        angle: (baseAngle + rotationQuarterTurns * 90) * math.pi / 180,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: panelFill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: isActive ? 1 : 0.30), width: isActive ? 3 : 1),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: const Color(0xFFD12E78).withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                playerName,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatTimer(remaining),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '長押しで一時停止',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimer(double seconds) {
    final totalSeconds = seconds.floor().clamp(0, 359999);
    final minutes = totalSeconds ~/ 60;
    final remainSeconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainSeconds.toString().padLeft(2, '0')}';
  }
}

class _TimerCenterControls extends StatelessWidget {
  const _TimerCenterControls({
    required this.statusText,
    required this.accent,
    required this.isDisabled,
    required this.onHome,
    required this.onReset,
    required this.onSettings,
    required this.onRotate,
  });

  final String statusText;
  final Color accent;
  final bool isDisabled;
  final VoidCallback onHome;
  final VoidCallback onReset;
  final VoidCallback onSettings;
  final VoidCallback onRotate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          statusText,
          style: const TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: isDisabled ? 0.45 : 1,
          child: IgnorePointer(
            ignoring: false,
            child: Row(
              children: [
                _TimerControlButton(icon: Icons.home_rounded, accent: accent, onPressed: onHome),
                _TimerControlButton(icon: Icons.refresh_rounded, accent: accent, onPressed: onReset),
                _TimerControlButton(icon: Icons.tune_rounded, accent: accent, onPressed: isDisabled ? () {} : onSettings),
                _TimerControlButton(icon: Icons.rotate_right_rounded, accent: accent, onPressed: onRotate),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerControlButton extends StatelessWidget {
  const _TimerControlButton({required this.icon, required this.accent, required this.onPressed});

  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: SizedBox(
          width: 46,
          height: 46,
          child: Material(
            color: accent.withValues(alpha: 0.16),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Icon(icon, color: accent, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerSettingCard extends StatelessWidget {
  const _TimerSettingCard({
    required this.playerName,
    required this.currentMinutes,
    required this.timerMinuteOptions,
    required this.timerMinuteLabel,
    required this.onPickerChange,
    required this.onAdjust,
  });

  final String playerName;
  final int currentMinutes;
  final List<int> timerMinuteOptions;
  final String Function(int minute) timerMinuteLabel;
  final ValueChanged<int> onPickerChange;
  final ValueChanged<int> onAdjust;

  @override
  Widget build(BuildContext context) {
    final selectionValue = _nearestOption(currentMinutes);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(playerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              DropdownButton<int>(
                value: selectionValue,
                underline: const SizedBox.shrink(),
                items: timerMinuteOptions
                    .map((minute) => DropdownMenuItem<int>(value: minute, child: Text(timerMinuteLabel(minute))))
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    onPickerChange(value);
                  }
                },
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => onAdjust(-1),
                child: const Icon(Icons.remove_rounded, size: 16),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    timerMinuteLabel(currentMinutes),
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () => onAdjust(1),
                child: const Icon(Icons.add_rounded, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _nearestOption(int minutes) {
    final clamped = minutes.clamp(0, 60);
    return timerMinuteOptions.reduce((current, next) {
      return (current - clamped).abs() <= (next - clamped).abs() ? current : next;
    });
  }
}