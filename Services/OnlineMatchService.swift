import Foundation

protocol OnlineMatchService {
    func connect(displayName: String) async throws -> String
    func disconnect()
    func findMatch(options: OnlineMatchmakingOptions) async throws
    func send(move: OnlineMoveModel) async throws
}

final class StubOnlineMatchService: OnlineMatchService {
    func connect(displayName: String) async throws -> String {
        // 将来: 認証・セッション接続処理
        return "stub-session-\(UUID().uuidString)"
    }

    func disconnect() {
        // 将来: セッション切断処理
    }

    func findMatch(options: OnlineMatchmakingOptions) async throws {
        // 将来: マッチメイキングAPI呼び出し
    }

    func send(move: OnlineMoveModel) async throws {
        // 将来: 着手送信API呼び出し
    }
}
