import SwiftUI

/// スタート画面 View（ContentView から抽出）
///
/// - 状態は一切持たない。すべてのアクションはコールバックで通知する。
struct StartScreenView: View {
    let onStartGame:           () -> Void
    let onOpenKifu:            () -> Void
    let onOpenURLRegistration: () -> Void
    let onOpenTimer:           () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Palette.info.opacity(0.06),
                    Color.white.opacity(0.04),
                    Palette.turnSente.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Palette.info.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 2)
                .offset(x: -150, y: -300)
            Circle()
                .fill(Palette.turnSente.opacity(0.10))
                .frame(width: 250, height: 250)
                .blur(radius: 2)
                .offset(x: 165, y: -210)

            VStack(spacing: 24) {
                Spacer(minLength: 0)

                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.95),
                                        Palette.info.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Palette.info.opacity(0.22), lineWidth: 1.2)

                        VStack(spacing: 14) {
                            Label("WELCOME", systemImage: "sparkles")
                                .font(.caption.bold())
                                .foregroundStyle(Palette.info)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Palette.info.opacity(0.12))
                                .clipShape(Capsule())

                            VStack(spacing: -4) {
                                Text("Hanafubuki")
                                    .font(Font.custom("TimesNewRomanPSMT", size: 17))
                                    .foregroundStyle(Palette.info.opacity(0.7))
                                    .tracking(1.0)

                                HStack(spacing: -2) {
                                    Text("87")
                                        .font(Font.custom("TimesNewRomanPS-BoldMT", size: 60))
                                    Text("吹棋")
                                        .font(.system(size: 54, weight: .heavy, design: .serif))
                                }
                                .tracking(0.2)
                            }
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Palette.info, Palette.turnSente],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Palette.info.opacity(0.2), radius: 3, x: 0.5, y: 1.5)

                            Text("持ち駒を打って王を詰ませよう")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 18) {
                                pieceIcon(symbol: "王", owner: .gote)
                                pieceIcon(symbol: "飛", owner: .sente)
                                pieceIcon(symbol: "角", owner: .gote)
                            }

                            HStack(spacing: 8) {
                                featureTag(text: "すぐ対局", icon: "bolt.fill")
                                featureTag(text: "検討対応", icon: "arrow.left.arrow.right")
                                featureTag(text: "KIF保存", icon: "square.and.arrow.down")
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 26)
                    }
                    .frame(maxWidth: 430)
                    .shadow(color: Palette.info.opacity(0.12), radius: 18, y: 8)
                }

                VStack(spacing: 12) {
                    Button(action: onStartGame) {
                        Label("対局", systemImage: "play.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                    }
                    .accessibilityHint("対局設定画面を開く")
                    .buttonStyle(StartScreenButtonStyle(tint: Palette.info, prominent: true))

                    Button(action: onOpenKifu) {
                        Label("棋譜", systemImage: "books.vertical")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .accessibilityHint("保存棋譜の閲覧と、ファイル読込・貼り付け読込を開く")
                    .buttonStyle(StartScreenButtonStyle(tint: Palette.info, prominent: false))

                    Button(action: onOpenURLRegistration) {
                        Label("URL登録", systemImage: "link.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .accessibilityHint("棋譜取得URLの登録画面を開く")
                    .buttonStyle(StartScreenButtonStyle(tint: Palette.info, prominent: false))

                    Button(action: onOpenTimer) {
                        Label("タイマー", systemImage: "timer")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .accessibilityHint("対局時計の設定画面を開く")
                    .buttonStyle(StartScreenButtonStyle(tint: Palette.info, prominent: false))
                }
                .frame(maxWidth: 330)

                Text("サクッと対局、あとからじっくり検討")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Private helpers

    /// 駒アイコン（スタート画面の装飾用）
    private func pieceIcon(symbol: String, owner: ShogiPlayer) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 62, height: 62)
                .overlay(
                    Circle()
                        .stroke(Palette.info.opacity(0.24), lineWidth: 1)
                )
            komaView(symbol: symbol, owner: owner, width: 36, height: 42, fontSize: 20)
        }
        .shadow(color: Palette.info.opacity(0.10), radius: 6, y: 3)
    }

    /// フィーチャータグ（スタート画面の説明用カプセル）
    private func featureTag(text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(Palette.info)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Palette.info.opacity(0.12))
            .overlay(
                Capsule()
                    .stroke(Palette.info.opacity(0.22), lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    /// 駒の見た目を描画（KomaShape + テキスト）
    private func komaView(symbol: String, owner: ShogiPlayer, width: CGFloat, height: CGFloat, fontSize: CGFloat) -> some View {
        ZStack {
            KomaShape()
                .fill(
                    LinearGradient(
                        colors: [Palette.pieceFillTop, Palette.pieceFillBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            KomaShape()
                .stroke(Palette.pieceBorder, lineWidth: max(1.2, min(width, height) * 0.05))
            Text(symbol)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(Palette.pieceText)
                .shadow(color: Palette.pieceShadow, radius: 0.5, x: 0, y: 0)
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(owner == .gote ? 180 : 0))
    }
}

#Preview {
    StartScreenView(
        onStartGame: {},
        onOpenKifu: {},
        onOpenURLRegistration: {},
        onOpenTimer: {}
    )
}
