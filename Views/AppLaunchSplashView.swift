import SwiftUI

/// アプリ起動時に表示するスプラッシュアニメーション
struct AppLaunchSplashView: View {
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var didStart = false
    @State private var markScale: CGFloat = 0.92
    @State private var lineRevealOpacity: Double = 0
    @State private var lineGlowOpacity: Double = 0
    @State private var lineGlowBlur: CGFloat = 14
    @State private var glowOpacity: Double = 0
    @State private var overlayOpacity: Double = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 240, height: 240)
                .blur(radius: 24)
                .scaleEffect(markScale * 1.04)
                .opacity(glowOpacity)

            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .mask(launchLogoMask)
                    .opacity(lineRevealOpacity)

                Rectangle()
                    .fill(Color.white)
                    .mask(launchLogoMask)
                    .blur(radius: lineGlowBlur)
                    .opacity(lineGlowOpacity)
            }
            .frame(width: 270, height: 270)
            .shadow(color: Color.white.opacity(0.16), radius: 8, y: 2)
            .scaleEffect(markScale)
        }
        .opacity(overlayOpacity)
        .onAppear {
            startAnimationIfNeeded()
        }
    }

    private func startAnimationIfNeeded() {
        guard !didStart else { return }
        didStart = true

        if reduceMotion {
            markScale = 1
            lineRevealOpacity = 1
            lineGlowOpacity = 0.10
            lineGlowBlur = 8
            glowOpacity = 0.18

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                withAnimation(.easeOut(duration: 0.36)) {
                    overlayOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                    isPresented = false
                }
            }
            return
        }

        withAnimation(.easeOut(duration: 1.90)) {
            lineRevealOpacity = 1
        }
        withAnimation(.spring(response: 0.92, dampingFraction: 0.86).delay(0.14)) {
            markScale = 1
        }
        withAnimation(.easeOut(duration: 0.95).delay(0.20)) {
            lineGlowOpacity = 0.26
            lineGlowBlur = 6
        }
        withAnimation(.easeOut(duration: 0.86).delay(1.24)) {
            lineGlowOpacity = 0.12
            lineGlowBlur = 9
        }
        withAnimation(.easeOut(duration: 0.90).delay(0.34)) {
            glowOpacity = 0.24
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.75) {
            withAnimation(.easeInOut(duration: 0.52)) {
                overlayOpacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.35) {
            isPresented = false
        }
    }

    private var launchLogoMask: some View {
        VStack(spacing: -8) {
            Text("87")
                .font(.system(size: 164, weight: .black, design: .rounded))
            Text("吹棋")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white)
    }
}
