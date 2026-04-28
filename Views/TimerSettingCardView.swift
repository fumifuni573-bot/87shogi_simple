import SwiftUI

// MARK: - TimerSettingCardView
//
// タイマー設定シートに表示する 1プレイヤー分の持ち時間設定カード。
// Picker + ±ボタン の純粋 UI View。
// ContentView から切り出し（P1-6）。

struct TimerSettingCardView: View {

    // MARK: - Parameters

    /// プレイヤー表示名
    let playerName: String
    /// 現在の持ち時間（分）
    let currentMinutes: Int
    /// 選択肢として表示する分数の配列
    let timerMinuteOptions: [Int]
    /// 分数を表示文字列に変換するクロージャ（例: 0 → "なし", 5 → "5分"）
    let timerMinuteLabel: (Int) -> String
    /// Picker でオプションが選ばれたときのコールバック（引数: 選択された分数）
    let onPickerChange: (Int) -> Void
    /// ±ボタンが押されたときのコールバック（引数: +1 または -1）
    let onAdjust: (Int) -> Void

    // MARK: - Body

    var body: some View {
        let selectionBinding = Binding<Int>(
            get: { nearestOption(to: currentMinutes) },
            set: { onPickerChange($0) }
        )

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(playerName)
                    .font(.caption.bold())
                Spacer()

                Picker("時間", selection: selectionBinding) {
                    ForEach(timerMinuteOptions, id: \.self) { minute in
                        Text(timerMinuteLabel(minute)).tag(minute)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Button {
                    onAdjust(-1)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.bold())
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)

                Text(timerMinuteLabel(currentMinutes))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    onAdjust(1)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Private Helpers

    /// 指定された分数に最も近い選択肢を返す
    private func nearestOption(to minutes: Int) -> Int {
        let clamped = min(60, max(0, minutes))
        return timerMinuteOptions.min(by: { abs($0 - clamped) < abs($1 - clamped) }) ?? 5
    }
}
