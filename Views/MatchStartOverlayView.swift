import SwiftUI

struct MatchStartOverlayView: View {
    let showFurigomaCue: Bool
    let showMatchStartCue: Bool
    let boardRect: CGRect
    let furigomaResults: [Bool]
    let furigomaRevealCount: Int
    let furigomaRouletteTick: Int
    let matchStartTopRole: String
    let matchStartBottomRole: String

    var body: some View {
        ZStack {
            if showFurigomaCue {
                furigomaCuePanel
                    .frame(width: boardRect.width, height: boardRect.height)
                    .position(x: boardRect.midX, y: boardRect.midY)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            matchStartCuePanel
                .frame(width: boardRect.width, height: boardRect.height)
                .position(x: boardRect.midX, y: boardRect.midY)
                .opacity(showMatchStartCue ? 1 : 0)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private var furigomaCuePanel: some View {
        let laneCount = furigomaResults.count
        let allRevealed = furigomaRevealCount >= laneCount
        let toCount = furigomaResults.filter { $0 }.count
        let fuCount = furigomaResults.count - toCount
        // と多い → 後手候補（上側）が先手。歩多い → 下側が先手
        let senteIsTop = toCount > fuCount

        return VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 18) {
                // タイトル＋誰の駒かラベル
                VStack(spacing: 6) {
                    Text("振り駒")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.55), radius: 3, x: 0, y: 1)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(Palette.turnGote)
                            .frame(width: 7, height: 7)
                        Text("後手候補（上側）の歩を振ります")
                            .font(.caption.bold())
                            .foregroundStyle(Palette.turnGote.opacity(0.90))
                    }
                }

                HStack(spacing: 8) {
                    ForEach(0..<laneCount, id: \.self) { idx in
                        furigomaLaneView(index: idx)
                    }
                }

                // 全枚公開後に結果を表示
                if allRevealed {
                    Text(senteIsTop ? "上側が先手" : "下側が先手")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.55), radius: 3, x: 0, y: 1)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: allRevealed)
                }
            }

            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
    }

    private func furigomaLaneView(index: Int) -> some View {
        let isRevealed = index < furigomaRevealCount
        let laneHeight: CGFloat = 56
        let spinTick = furigomaRouletteTick + index * 3
        let spinningIsTo = (spinTick % 2) == 0
        let currentSymbol = isRevealed ? (furigomaResults[index] ? "と" : "歩") : (spinningIsTo ? "と" : "歩")
        let spinAngle = isRevealed ? 0.0 : Double((spinTick % 8) * 45)
        let bounce = isRevealed ? 0.0 : sin(Double(spinTick) * 0.55 + Double(index)) * 3.0

        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.14))

            Text(currentSymbol)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(spinAngle))
                .rotation3DEffect(
                    .degrees(isRevealed ? 0 : Double((spinTick % 6) * 20)),
                    axis: (x: 1, y: 0, z: 0)
                )
                .offset(y: bounce)
                .animation(.linear(duration: 0.11), value: furigomaRouletteTick)
                .animation(.spring(response: 0.24, dampingFraction: 0.75), value: furigomaRevealCount)
        }
        .frame(width: 44, height: laneHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .compositingGroup()
    }

    private var matchStartCuePanel: some View {
        VStack(spacing: 0) {
            Text(matchStartTopRole)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Color.black.opacity(0.55), radius: 3, x: 0, y: 1)
                .rotationEffect(.degrees(180))
                .padding(.top, 48)

            Spacer(minLength: 12)

            Text("対局開始")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Color.black.opacity(0.55), radius: 3, x: 0, y: 1)

            Spacer(minLength: 12)

            Text(matchStartBottomRole)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Color.black.opacity(0.55), radius: 3, x: 0, y: 1)
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
    }
}
