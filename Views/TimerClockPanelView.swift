import SwiftUI

// MARK: - TimerClockPanelView
//
// タイマー画面に表示する1プレイヤー分の時計パネル。
// 先手・後手いずれか一方に渡す純粋 UI View。
// ContentView から切り出し（P1-6）。

struct TimerClockPanelView: View {

    // MARK: - Parameters

    /// プレイヤー表示名
    let playerName: String
    /// 表示する残り時間（秒）
    let remaining: TimeInterval
    /// このパネルが現在の手番かどうか
    let isActive: Bool
    /// このプレイヤーの時間切れフラグ
    let hasExpired: Bool
    /// 上側パネルかどうか（回転方向の基準点を決める）
    let isTopPanel: Bool
    /// タイマー画面の回転量（0〜3 の四分の一回転数）
    let rotationQuarterTurns: Int
    /// パネルタップ時のコールバック
    let onTap: () -> Void
    /// 長押し（一時停止）時のコールバック
    let onLongPress: () -> Void

    // MARK: - Body

    var body: some View {
        let isSideways = rotationQuarterTurns % 2 != 0
        let baseAngle = isSideways ? 0 : (isTopPanel ? 180 : 0)

        let activeFill = LinearGradient(
            colors: [Color(red: 0.82, green: 0.18, blue: 0.47), Color(red: 0.70, green: 0.12, blue: 0.40)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let waitingFill = LinearGradient(
            colors: [Color(red: 0.88, green: 0.76, blue: 0.82), Color(red: 0.80, green: 0.64, blue: 0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let panelFill: AnyShapeStyle = hasExpired
            ? AnyShapeStyle(Palette.danger)
            : (isActive ? AnyShapeStyle(activeFill) : AnyShapeStyle(waitingFill))

        ZStack {
            VStack(spacing: 10) {
                Text(playerName)
                    .font(.footnote.weight(.semibold))
                    .opacity(0.9)
                Text(formattedTimer(remaining))
                    .font(.system(size: 70, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                Text("長押しで一時停止")
                    .font(.caption2)
                    .opacity(0.82)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(panelFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(isActive ? 1.0 : 0.30), lineWidth: isActive ? 3.0 : 1.0)
            )
            .shadow(
                color: isActive ? Color(red: 0.82, green: 0.18, blue: 0.47).opacity(0.45) : Color.clear,
                radius: isActive ? 14 : 0,
                y: 0
            )
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress()
        }
        .rotationEffect(.degrees(Double(baseAngle + rotationQuarterTurns * 90)))
    }

    // MARK: - Private Helpers

    /// TimeInterval を "MM:SS" 形式にフォーマット
    private func formattedTimer(_ seconds: TimeInterval) -> String {
        let wholeSeconds = Int(max(0, seconds).rounded(.down))
        let minutes = wholeSeconds / 60
        let sec = wholeSeconds % 60
        return String(format: "%02d:%02d", minutes, sec)
    }
}
