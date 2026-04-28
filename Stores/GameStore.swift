import Foundation
import Combine

final class GameStore: ObservableObject {
    @Published var board: [[ContentView.Piece?]] = ContentView.initialBoard()
    @Published var senteHand: [ContentView.PieceType: Int] = [:]
    @Published var goteHand: [ContentView.PieceType: Int] = [:]
    @Published var suppressGameEndPopup: Bool = false
    @Published var showFurigomaCue: Bool = false
    @Published var furigomaResults: [Bool] = Array(repeating: false, count: MatchStartLogic.furigomaPieceCount)
    @Published var furigomaRevealCount: Int = 0
    @Published var furigomaRouletteTick: Int = 0
    @Published var furigomaResultMessage: String = ""
    @Published var selectedHandicap: ContentView.GameHandicap = .none
    @Published var boardMotionTick: Int = 0
    @Published var showStartScreen: Bool = true
    @Published var showGameEndPopup: Bool = false
    @Published var isReviewMode: Bool = false
    @Published var showMatchStartCue: Bool = false
    @Published var selected: ContentView.Square? = nil
    @Published var selectedDropType: ContentView.PieceType? = nil
    @Published var pendingPromotionMove: ContentView.PendingPromotionMove? = nil
    @Published var reviewIndex: Int = 0
    @Published var positionCounts: [String: Int] = [:]
    @Published var moveHistory: [ContentView.GameSnapshot] = []
    @Published var moveRecords: [String] = []
    @Published var turn: ContentView.Player = .sente
    @Published var winner: ContentView.Player? = nil
    @Published var winReason: String = "詰み"
    @Published var isSennichite: Bool = false
    @Published var isInterrupted: Bool = false
    @Published var statusMessage: String = "駒を選んで移動してください"
}
