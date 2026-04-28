import Foundation

enum MatchStartLogic {
    static let furigomaPieceCount = 5
    static let furigomaRevealStep: TimeInterval = 0.22
    static let furigomaRevealTail: TimeInterval = 0.18
    static let furigomaResultHold: TimeInterval = 1.2
    static let furigomaSpinInterval: TimeInterval = 0.09
    static let matchStartCueDuration: TimeInterval = 1.2

    static func shouldUseFurigoma(handicap: ContentView.GameHandicap) -> Bool {
        handicap == .none
    }

    static func defaultOpeningTurn(handicap: ContentView.GameHandicap) -> ContentView.Player {
        // 駒落ちは従来どおり下側先手で開始
        _ = handicap
        return .sente
    }

    static func randomFurigomaResults() -> [Bool] {
        (0..<furigomaPieceCount).map { _ in Bool.random() }
    }

    static func revealDelay(at index: Int) -> TimeInterval {
        furigomaRevealStep * Double(index + 1)
    }

    static func revealFinishedDelay(pieceCount: Int) -> TimeInterval {
        furigomaRevealStep * Double(pieceCount) + furigomaRevealTail
    }

    static func openingTurn(from furigomaResults: [Bool]) -> ContentView.Player {
        let toCount = furigomaResults.filter { $0 }.count
        let fuCount = furigomaResults.count - toCount
        return fuCount > toCount ? .sente : .gote
    }

    static func furigomaSummary(results: [Bool]) -> String {
        let toCount = results.filter { $0 }.count
        let fuCount = results.count - toCount
        return "振り駒（歩\(fuCount)・と\(toCount)）"
    }
}
