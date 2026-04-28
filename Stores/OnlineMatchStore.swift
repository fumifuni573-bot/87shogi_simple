import Foundation
import Combine

@MainActor
final class OnlineMatchStore: ObservableObject {
    @Published private(set) var connectionState: OnlineMatchConnectionState = .idle
    @Published private(set) var outgoingMoves: [OnlineMoveModel] = []
    @Published private(set) var lastErrorMessage: String?

    private let service: OnlineMatchService

    init(service: OnlineMatchService? = nil) {
        self.service = service ?? StubOnlineMatchService()
    }

    func connect(displayName: String) async {
        connectionState = .connecting
        lastErrorMessage = nil

        do {
            let sessionId = try await service.connect(displayName: displayName)
            connectionState = .connected(sessionId: sessionId)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "オンライン接続に失敗しました"
            connectionState = .failed(message: message)
            lastErrorMessage = message
        }
    }

    func disconnect() {
        service.disconnect()
        connectionState = .disconnected(reason: "ユーザーが切断しました")
    }

    func findMatch(options: OnlineMatchmakingOptions) async {
        do {
            try await service.findMatch(options: options)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "マッチングに失敗しました"
            connectionState = .failed(message: message)
            lastErrorMessage = message
        }
    }

    func send(moveText: String) async {
        let move = OnlineMoveModel(moveText: moveText)
        do {
            try await service.send(move: move)
            outgoingMoves.append(move)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "着手送信に失敗しました"
            connectionState = .failed(message: message)
            lastErrorMessage = message
        }
    }
}
