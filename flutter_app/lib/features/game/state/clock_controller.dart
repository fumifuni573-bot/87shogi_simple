import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/shogi_models.dart';
import '../../../logic/clock_logic.dart';

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

  void resetToInitialValues() {
    resetClocks(
      sente: state.senteInitialSeconds,
      gote: state.goteInitialSeconds,
      byoYomi: state.byoYomiSeconds,
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

  double displaySecondsFor(ShogiPlayer player) {
    final main = player == ShogiPlayer.sente ? state.senteClockRemaining : state.goteClockRemaining;
    final byo = player == ShogiPlayer.sente ? state.senteByoYomiRemaining : state.goteByoYomiRemaining;
    return ClockLogic.displaySeconds(
      main: main,
      byoYomiRemaining: byo,
      byoYomiSeconds: state.byoYomiSeconds,
    );
  }

  void pauseTimer() {
    if (!state.isTimerRunning) {
      return;
    }
    state = state.copyWith(
      isTimerRunning: false,
      timerLastUpdate: DateTime.now(),
    );
  }

  void handleStandaloneTap(ShogiPlayer player) {
    if (state.timerExpiredPlayer != null) {
      return;
    }

    if (!state.isTimerRunning) {
      final nextPlayer = player.opposite;
      _prepareByoYomiForTurnStart(nextPlayer);
      state = state.copyWith(
        timerActivePlayer: nextPlayer,
        isTimerRunning: true,
        timerLastUpdate: DateTime.now(),
      );
      return;
    }

    if (state.timerActivePlayer != player) {
      return;
    }

    final nextPlayer = player.opposite;
    _prepareByoYomiForTurnStart(nextPlayer);
    state = state.copyWith(
      timerActivePlayer: nextPlayer,
      timerLastUpdate: DateTime.now(),
    );
  }

  void tick(DateTime now) {
    if (!state.isTimerRunning || state.timerActivePlayer == null) {
      state = state.copyWith(timerLastUpdate: now);
      return;
    }

    final elapsed = now.difference(state.timerLastUpdate).inMilliseconds / 1000;
    state = state.copyWith(timerLastUpdate: now);
    if (elapsed <= 0) {
      return;
    }

    if (state.timerActivePlayer == ShogiPlayer.sente) {
      _tickActivePlayer(ShogiPlayer.sente, elapsed);
      return;
    }
    _tickActivePlayer(ShogiPlayer.gote, elapsed);
  }

  void _tickActivePlayer(ShogiPlayer player, double elapsed) {
    final main = player == ShogiPlayer.sente ? state.senteClockRemaining : state.goteClockRemaining;
    var remainder = elapsed;
    var nextMain = main;

    if (nextMain > 0) {
      final consumeMain = nextMain < remainder ? nextMain : remainder;
      nextMain -= consumeMain;
      remainder -= consumeMain;
    }

    double nextByo = player == ShogiPlayer.sente ? state.senteByoYomiRemaining : state.goteByoYomiRemaining;
    if (remainder > 0 || nextMain <= 0) {
      final result = ClockLogic.consumeByoYomi(
        currentRemaining: nextByo,
        byoYomiSeconds: state.byoYomiSeconds,
        elapsed: remainder,
      );
      nextByo = result.remaining;
      if (!result.alive) {
        _expire(player);
        return;
      }
    }

    if (player == ShogiPlayer.sente) {
      state = state.copyWith(
        senteClockRemaining: nextMain,
        senteByoYomiRemaining: nextByo,
      );
    } else {
      state = state.copyWith(
        goteClockRemaining: nextMain,
        goteByoYomiRemaining: nextByo,
      );
    }
  }

  void _prepareByoYomiForTurnStart(ShogiPlayer player) {
    final main = player == ShogiPlayer.sente ? state.senteClockRemaining : state.goteClockRemaining;
    final prepared = ClockLogic.preparedByoYomiRemaining(
      main: main,
      byoYomiSeconds: state.byoYomiSeconds,
    );
    if (prepared == null) {
      return;
    }

    if (player == ShogiPlayer.sente) {
      state = state.copyWith(senteByoYomiRemaining: prepared);
    } else {
      state = state.copyWith(goteByoYomiRemaining: prepared);
    }
  }

  void _expire(ShogiPlayer loser) {
    state = state.copyWith(
      timerExpiredPlayer: loser,
      timerActivePlayer: null,
      isTimerRunning: false,
      senteClockRemaining: loser == ShogiPlayer.sente ? 0 : state.senteClockRemaining,
      goteClockRemaining: loser == ShogiPlayer.gote ? 0 : state.goteClockRemaining,
      senteByoYomiRemaining: loser == ShogiPlayer.sente ? 0 : state.senteByoYomiRemaining,
      goteByoYomiRemaining: loser == ShogiPlayer.gote ? 0 : state.goteByoYomiRemaining,
    );
  }
}