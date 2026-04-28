import SwiftUI

struct TimerCenterControlsView: View {
    private let showsBannerAd = false

    let accent: Color
    let isDisabled: Bool
    let onHome: () -> Void
    let onReset: () -> Void
    let onSettings: () -> Void
    let onRotate: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                controlButton(systemName: "house.fill", action: onHome)
                controlButton(systemName: "arrow.counterclockwise", action: onReset)
                controlButton(systemName: "slider.horizontal.3", action: onSettings)
                controlButton(systemName: "rotate.right", action: onRotate)
            }
            .frame(maxWidth: .infinity)

            if showsBannerAd {
                bannerAdSpace
            }
        }
        .padding(.vertical, 4)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1.0)
    }

    private func controlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 46, height: 46)
                .background(accent.opacity(0.16), in: Circle())
                .overlay(Circle().stroke(accent.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var bannerAdSpace: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.45))
            .frame(maxWidth: 360)
            .frame(height: 54)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accent.opacity(0.30), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
            )
            .overlay(
                Text("Banner Ad")
                    .font(.caption.bold())
                    .foregroundStyle(accent.opacity(0.85))
            )
    }
}
