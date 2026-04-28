class ClockLogic {
  static double displaySeconds({
    required double main,
    required double byoYomiRemaining,
    required int byoYomiSeconds,
  }) {
    if (main > 0) {
      return main;
    }
    if (byoYomiSeconds <= 0) {
      return 0;
    }
    return byoYomiRemaining;
  }

  static double? preparedByoYomiRemaining({
    required double main,
    required int byoYomiSeconds,
  }) {
    if (byoYomiSeconds <= 0 || main > 0) {
      return null;
    }
    return byoYomiSeconds.toDouble();
  }

  static ({double remaining, bool alive}) consumeByoYomi({
    required double currentRemaining,
    required int byoYomiSeconds,
    required double elapsed,
  }) {
    if (byoYomiSeconds <= 0) {
      return (remaining: 0, alive: false);
    }
    final fallback = byoYomiSeconds.toDouble();
    final base = currentRemaining > 0 ? currentRemaining : fallback;
    final remaining = (base - elapsed).clamp(0, double.infinity).toDouble();
    return (remaining: remaining, alive: remaining > 0);
  }
}