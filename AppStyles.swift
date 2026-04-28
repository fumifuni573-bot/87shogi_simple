import SwiftUI

// MARK: - App-wide color palette

/// アプリ全体のカラーパレット（UIテーマ用）
/// 花吹雪（はなふぶき）を連想させる色彩（白背景 + ピンク基調）
enum Palette {
    // 背景：視認性重視の白ベース
    static let bgTop    = Color(red: 1.00, green: 1.00, blue: 1.00)
    static let bgBottom = Color(red: 0.98, green: 0.98, blue: 0.99)

    // カード背景：白寄り
    static let cardBg = Color(red: 0.99, green: 0.99, blue: 1.00)

    // ターン表示：深いピンク系
    static let turnSente = Color(red: 0.82, green: 0.18, blue: 0.47)
    static let turnGote  = Color(red: 0.72, green: 0.24, blue: 0.48)

    // メインカラー：強調は深いピンク
    static let info    = Color(red: 0.82, green: 0.18, blue: 0.47)
    static let review  = Color(red: 0.74, green: 0.12, blue: 0.40)
    static let danger  = Color(red: 0.78, green: 0.14, blue: 0.30)
    static let warning = Color(red: 0.86, green: 0.52, blue: 0.40)
    static let neutral = Color(red: 0.42, green: 0.42, blue: 0.46)

    // 盤面：金色系（春の日差し）
    static let boardLight = Color(red: 0.98, green: 0.92, blue: 0.75)  // 淡い金色
    static let boardDark  = Color(red: 0.95, green: 0.85, blue: 0.65)  // より濃い金色
    static let boardFrame = Color(red: 0.70, green: 0.55, blue: 0.35)  // 茶色（春木）

    // ヒント：深いピンク
    static let hintUnified     = Color(red: 0.82, green: 0.18, blue: 0.47)
    static let hintMove        = hintUnified
    static let hintCapture     = hintUnified
    static let hintSelected    = hintUnified
    static let hintSelectedBorder = hintUnified

    // 駒：従来配色
    static let pieceText      = Color.black
    static let pieceShadow    = Color.white.opacity(0.35)
    static let pieceFillTop   = Color(red: 0.93, green: 0.84, blue: 0.61)
    static let pieceFillBottom = Color(red: 0.91, green: 0.78, blue: 0.49)
    static let pieceBorder    = Color.black.opacity(0.92)
}

// MARK: - Piece shape (pentagon)

/// 将棋の駒の五角形シェイプ
struct KomaShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let topY     = rect.minY + rect.height * 0.02
        let shoulderY = rect.minY + rect.height * 0.17

        path.move(to: CGPoint(x: rect.midX, y: topY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: shoulderY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.03, y: rect.maxY - rect.height * 0.02))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.03, y: rect.maxY - rect.height * 0.02))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.16, y: shoulderY))
        path.closeSubpath()

        return path
    }
}

// MARK: - Button styles

/// ポップアップ・ダイアログ用ボタンスタイル
struct PopupButtonStyle: ButtonStyle {
    var prominent: Bool = false
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(prominent ? .white : tint)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        prominent
                            ? tint.opacity(configuration.isPressed ? 0.62 : 1.0)
                            : tint.opacity(configuration.isPressed ? 0.22 : 0.10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(tint.opacity(prominent ? 0 : (configuration.isPressed ? 1.0 : 0.55)), lineWidth: 1.5)
                    )
            )
            .shadow(color: tint.opacity(prominent && !configuration.isPressed ? 0.38 : 0), radius: 7, y: 4)
            .scaleEffect(configuration.isPressed ? 0.91 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.14, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// スタート画面専用のボタンスタイル
struct StartScreenButtonStyle: ButtonStyle {
    var tint: Color
    var prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Color.white : tint)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        prominent
                            ? LinearGradient(
                                colors: [tint.opacity(configuration.isPressed ? 0.75 : 1.0), tint.opacity(configuration.isPressed ? 0.92 : 0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(configuration.isPressed ? 0.85 : 0.96), Color.white.opacity(configuration.isPressed ? 0.78 : 0.88)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(tint.opacity(prominent ? 0 : (configuration.isPressed ? 0.70 : 0.32)), lineWidth: 1.2)
                    )
            )
            .shadow(color: Color.black.opacity(prominent ? 0.18 : 0.06), radius: prominent ? 12 : 6, y: prominent ? 6 : 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.16, dampingFraction: 0.62), value: configuration.isPressed)
    }
}
