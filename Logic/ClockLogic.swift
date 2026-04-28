import Foundation

enum ClockLogic {
    static func displaySeconds(main: TimeInterval, byoYomiRemaining: TimeInterval, byoYomiSeconds: Int) -> TimeInterval {
        if main > 0 { return main }
        guard byoYomiSeconds > 0 else { return 0 }
        return byoYomiRemaining
    }

    static func preparedByoYomiRemaining(main: TimeInterval, byoYomiSeconds: Int) -> TimeInterval? {
        guard byoYomiSeconds > 0, main <= 0 else { return nil }
        return TimeInterval(byoYomiSeconds)
    }

    static func consumeByoYomi(
        currentRemaining: TimeInterval,
        byoYomiSeconds: Int,
        elapsed: TimeInterval
    ) -> (remaining: TimeInterval, alive: Bool) {
        guard byoYomiSeconds > 0 else { return (0, false) }
        let fallback = TimeInterval(byoYomiSeconds)
        let base = currentRemaining > 0 ? currentRemaining : fallback
        let remaining = max(0, base - elapsed)
        return (remaining, remaining > 0)
    }
}
