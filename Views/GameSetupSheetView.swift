import SwiftUI

struct GameSetupSheetView: View {
    @Binding var selectedHandicap: ContentView.GameHandicap
    @Binding var sharedTimerMinutes: Int
    @Binding var byoYomiSeconds: Int

    let timerMinuteOptions: [Int]
    let timerMinuteLabel: (Int) -> String
    let byoYomiSecondOptions: [Int]
    let handicapDescription: String
    let cardBackground: Color
    let accentTint: Color

    let onAppearSyncSharedMinutes: () -> Void
    let onStart: () -> Void
    let onCancel: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("対局設定")
                        .font(.title2.bold())
                    Text("駒落ちを選択して対局を開始できます")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("駒落ち")
                        .font(.headline)
                    Picker("駒落ち", selection: $selectedHandicap) {
                        ForEach(ContentView.GameHandicap.allCases) { handicap in
                            Text(handicap.rawValue).tag(handicap)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(handicapDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text("時間設定")
                        .font(.headline)

                    HStack {
                        Text("持ち時間")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("持ち時間", selection: $sharedTimerMinutes) {
                            ForEach(timerMinuteOptions, id: \.self) { minute in
                                Text(timerMinuteLabel(minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text("切れたら一手")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("切れたら何秒", selection: $byoYomiSeconds) {
                            ForEach(byoYomiSecondOptions, id: \.self) { second in
                                Text(second == 0 ? "なし" : "\(second)秒").tag(second)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onAppear {
                    onAppearSyncSharedMinutes()
                }

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button(action: onStart) {
                        Label("この設定で対局開始", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentTint)

                    Button("キャンセル", action: onCancel)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .navigationTitle("対局前設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", action: onClose)
                }
            }
        }
    }
}
