import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/shogi_models.dart';

class ClockState {
  const ClockState({
    required this.senteInitialSeconds,
    required this.goteInitialSeconds,
    required this.senteClockRemaining,
    required this.goteClockRemaining,
    required this.byoYomiSeconds,
    required this.senteByoYomiRemaining,
    required this.goteByoYomiRemaining,
    required this.timerActivePlayer,
    required this.isTimerRunning,
    required this.timerExpiredPlayer,
    required this.timerLastUpdate,
    required this.timerRotationQuarterTurns,
  });

  factory ClockState.initial() {
    final now = DateTime.now();
    return ClockState(
      senteInitialSeconds: 600,
      goteInitialSeconds: 600,
      senteClockRemaining: 600,
      goteClockRemaining: 600,
      byoYomiSeconds: 0,
      senteByoYomiRemaining: 0,
      goteByoYomiRemaining: 0,
      timerActivePlayer: null,
      isTimerRunning: false,
      timerExpiredPlayer: null,
      timerLastUpdate: now,
      timerRotationQuarterTurns: 0,
    );
  }

  final double senteInitialSeconds;
  final double goteInitialSeconds;
  final double senteClockRemaining;
  final double goteClockRemaining;
  final int byoYomiSeconds;
  final double senteByoYomiRemaining;
  final double goteByoYomiRemaining;
  final ShogiPlayer? timerActivePlayer;
  final bool isTimerRunning;
  final ShogiPlayer? timerExpiredPlayer;
  final DateTime timerLastUpdate;
  final int timerRotationQuarterTurns;

  ClockState copyWith({
    double? senteInitialSeconds,
    double? goteInitialSeconds,
    double? senteClockRemaining,
    double? goteClockRemaining,
    int? byoYomiSeconds,
    double? senteByoYomiRemaining,
    double? goteByoYomiRemaining,
    ShogiPlayer? timerActivePlayer,
    bool clearTimerActivePlayer = false,
    bool? isTimerRunning,
    ShogiPlayer? timerExpiredPlayer,
    bool clearTimerExpiredPlayer = false,
    DateTime? timerLastUpdate,
    int? timerRotationQuarterTurns,
  }) {
    return ClockState(
      senteInitialSeconds: senteInitialSeconds ?? this.senteInitialSeconds,
      goteInitialSeconds: goteInitialSeconds ?? this.goteInitialSeconds,
      senteClockRemaining: senteClockRemaining ?? this.senteClockRemaining,
      goteClockRemaining: goteClockRemaining ?? this.goteClockRemaining,
      byoYomiSeconds: byoYomiSeconds ?? this.byoYomiSeconds,
      senteByoYomiRemaining: senteByoYomiRemaining ?? this.senteByoYomiRemaining,
      goteByoYomiRemaining: goteByoYomiRemaining ?? this.goteByoYomiRemaining,
      timerActivePlayer: clearTimerActivePlayer ? null : (timerActivePlayer ?? this.timerActivePlayer),
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
      timerExpiredPlayer:
          clearTimerExpiredPlayer ? null : (timerExpiredPlayer ?? this.timerExpiredPlayer),
      timerLastUpdate: timerLastUpdate ?? this.timerLastUpdate,
      timerRotationQuarterTurns: timerRotationQuarterTurns ?? this.timerRotationQuarterTurns,
    );
  }
}

class ClockController extends Notifier<ClockState> {
  @override
  ClockState build() => ClockState.initial();

  void resetClocks({required double sente, required double gote, required int byoYomi}) {
    final now = DateTime.now();
    state = ClockState(
      senteInitialSeconds: sente,
      goteInitialSeconds: gote,
      senteClockRemaining: sente,
      goteClockRemaining: gote,
      byoYomiSeconds: byoYomi,
      senteByoYomiRemaining: 0,
      goteByoYomiRemaining: 0,
      timerActivePlayer: null,
      isTimerRunning: false,
      timerExpiredPlayer: null,
      timerLastUpdate: now,
      timerRotationQuarterTurns: 0,
    );
  }

  void setTimerRunning(bool isRunning) {
    state = state.copyWith(
      isTimerRunning: isRunning,
      timerLastUpdate: DateTime.now(),
    );
  }

  void setActivePlayer(ShogiPlayer? player) {
    state = state.copyWith(
      timerActivePlayer: player,
      clearTimerActivePlayer: player == null,
    );
  }

  void setRemaining({double? sente, double? gote}) {
    state = state.copyWith(
      senteClockRemaining: sente ?? state.senteClockRemaining,
      goteClockRemaining: gote ?? state.goteClockRemaining,
      timerLastUpdate: DateTime.now(),
    );
  }

  void setByoYomiRemaining({double? sente, double? gote}) {
    state = state.copyWith(
      senteByoYomiRemaining: sente ?? state.senteByoYomiRemaining,
      goteByoYomiRemaining: gote ?? state.goteByoYomiRemaining,
    );
  }

  void setExpiredPlayer(ShogiPlayer? player) {
    state = state.copyWith(
      timerExpiredPlayer: player,
      clearTimerExpiredPlayer: player == null,
    );
  }

  void setRotationQuarterTurns(int turns) {
    state = state.copyWith(timerRotationQuarterTurns: turns % 4);
  }

  void setByoYomiSeconds(int seconds) {
    state = state.copyWith(byoYomiSeconds: seconds);
  }
}