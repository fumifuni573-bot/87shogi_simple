import Foundation

// 将来の「解析機能」「オンライン対戦機能」実装に向けた共通モデル群。

struct AnalysisRequestModel: Identifiable {
    let id: UUID
    let snapshot: ShogiGameSnapshot
    let requestedAt: Date
    let maxPrincipalVariations: Int
    let thinkingTimeMs: Int

    init(
        id: UUID = UUID(),
        snapshot: ShogiGameSnapshot,
        requestedAt: Date = Date(),
        maxPrincipalVariations: Int = 3,
        thinkingTimeMs: Int = 1200
    ) {
        self.id = id
        self.snapshot = snapshot
        self.requestedAt = requestedAt
        self.maxPrincipalVariations = max(1, maxPrincipalVariations)
        self.thinkingTimeMs = max(100, thinkingTimeMs)
    }
}

struct AnalysisLineModel: Identifiable, Equatable {
    let id: UUID
    let moves: [String]
    let scoreCp: Int
    let depth: Int

    init(id: UUID = UUID(), moves: [String], scoreCp: Int, depth: Int) {
        self.id = id
        self.moves = moves
        self.scoreCp = scoreCp
        self.depth = depth
    }
}

struct AnalysisResultModel: Equatable {
    let requestId: UUID
    let completedAt: Date
    let lines: [AnalysisLineModel]

    init(requestId: UUID, completedAt: Date = Date(), lines: [AnalysisLineModel]) {
        self.requestId = requestId
        self.completedAt = completedAt
        self.lines = lines
    }
}

enum OnlineMatchConnectionState: Equatable {
    case idle
    case connecting
    case connected(sessionId: String)
    case disconnected(reason: String)
    case failed(message: String)
}

struct OnlineMatchmakingOptions: Equatable {
    var preferredByoYomiSeconds: Int
    var preferredInitialMinutes: Int
    var rated: Bool

    init(preferredByoYomiSeconds: Int = 0, preferredInitialMinutes: Int = 10, rated: Bool = false) {
        self.preferredByoYomiSeconds = max(0, preferredByoYomiSeconds)
        self.preferredInitialMinutes = max(1, preferredInitialMinutes)
        self.rated = rated
    }
}

struct OnlineMoveModel: Equatable {
    let moveText: String
    let playedAt: Date

    init(moveText: String, playedAt: Date = Date()) {
        self.moveText = moveText
        self.playedAt = playedAt
    }
}
