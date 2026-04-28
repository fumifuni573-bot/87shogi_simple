import Foundation
import Combine
import SwiftUI

final class ClockStore: ObservableObject {
    @Published var senteInitialSeconds: TimeInterval = 600
    @Published var goteInitialSeconds: TimeInterval = 600
    @Published var senteClockRemaining: TimeInterval = 600
    @Published var goteClockRemaining: TimeInterval = 600
    @Published var byoYomiSeconds: Int = 0
    @Published var senteByoYomiRemaining: TimeInterval = 0
    @Published var goteByoYomiRemaining: TimeInterval = 0
    @Published var timerActivePlayer: ContentView.Player? = nil
    @Published var isTimerRunning: Bool = false {
        didSet {
            guard oldValue != isTimerRunning else { return }
            updateTimerTickerState()
        }
    }
    @Published var timerExpiredPlayer: ContentView.Player? = nil
    @Published var timerLastUpdate: Date = Date()
    @Published var timerRotationQuarterTurns: Int = 0
    
    // タイマーのTick用（必要時のみ発火して省電力化）
    let timerTicker = PassthroughSubject<Date, Never>()
    private var timerTickCancellable: AnyCancellable?
    
    func resetClocks(sente: TimeInterval, gote: TimeInterval, byoYomi: Int) {
        senteInitialSeconds = sente
        goteInitialSeconds = gote
        senteClockRemaining = sente
        goteClockRemaining = gote
        byoYomiSeconds = byoYomi
        senteByoYomiRemaining = 0
        goteByoYomiRemaining = 0
        timerActivePlayer = nil
        isTimerRunning = false
        timerExpiredPlayer = nil
        timerLastUpdate = Date()
        timerRotationQuarterTurns = 0
    }

    deinit {
        timerTickCancellable?.cancel()
    }

    private func updateTimerTickerState() {
        if isTimerRunning {
            guard timerTickCancellable == nil else { return }
            timerTickCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] now in
                    self?.timerTicker.send(now)
                }
            return
        }

        timerTickCancellable?.cancel()
        timerTickCancellable = nil
    }
}
