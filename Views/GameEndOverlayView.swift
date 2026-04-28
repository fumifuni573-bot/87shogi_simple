import SwiftUI

struct GameEndOverlayView: View {
    let title: String
    let subtitle: String
    let titleColor: Color
    let tint: Color
    let onReview: () -> Void
    let onSaveKif: () -> Void
    let onExportKif: () -> Void
    let onRematch: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(titleColor)
                        .multilineTextAlignment(.center)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 4)

                VStack(spacing: 10) {
                    Button(action: onReview) {
                        Label("検討", systemImage: "magnifyingglass")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .accessibilityHint("終局局面を検討モードで開く")
                    .buttonStyle(PopupButtonStyle(prominent: true, tint: tint))

                    HStack(spacing: 10) {
                        Button(action: onSaveKif) {
                            Label("KIF保存", systemImage: "square.and.arrow.down")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .accessibilityHint("棋譜をKIF形式で保存する")
                        .buttonStyle(PopupButtonStyle(prominent: false, tint: tint))

                        Button(action: onExportKif) {
                            Label("KIF出力", systemImage: "square.and.arrow.up")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .accessibilityHint("棋譜をKIFファイルとして書き出す")
                        .buttonStyle(PopupButtonStyle(prominent: false, tint: tint))
                    }

                    HStack(spacing: 10) {
                        Button(action: onRematch) {
                            Label("再対局", systemImage: "arrow.clockwise")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .accessibilityHint("もう一度対局設定を開く")
                        .buttonStyle(PopupButtonStyle(prominent: false, tint: tint))

                        Button(action: onHome) {
                            Label("ホームに戻る", systemImage: "house.fill")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .accessibilityHint("スタート画面へ戻る")
                        .buttonStyle(PopupButtonStyle(prominent: false, tint: tint))
                    }
                }
            }
            .padding(28)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(radius: 24, y: 10)
            .padding(.horizontal, 36)
        }
    }
}
