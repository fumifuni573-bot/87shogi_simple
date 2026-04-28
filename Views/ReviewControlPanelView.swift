import SwiftUI

struct ReviewControlPanelView: View {
    let tint: Color
    let isAtStart: Bool
    let isAtEnd: Bool
    let currentIndex: Int
    let maxIndex: Int
    let onStart: () -> Void
    let onBack: () -> Void
    let onForward: () -> Void
    let onEnd: () -> Void
    let onScrub: (Int) -> Void
    let onResume: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { Double(currentIndex) },
                        set: { onScrub(Int($0.rounded())) }
                    ),
                    in: 0...Double(max(maxIndex, 0)),
                    step: 1
                )
                .tint(tint)
                .disabled(maxIndex <= 0)

                HStack {
                    Text("0手目")
                    Spacer()
                    Text("\(currentIndex) / \(maxIndex)")
                        .font(.caption.bold())
                        .foregroundStyle(tint)
                    Spacer()
                    Text("\(maxIndex)手目")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                navButton(systemName: "backward.end.fill", disabled: isAtStart, accessibility: "初期局面", action: onStart)
                navButton(systemName: "chevron.backward", disabled: isAtStart, accessibility: "1手戻す", action: onBack)
                navButton(systemName: "chevron.forward", disabled: isAtEnd, accessibility: "1手進む", action: onForward)
                navButton(systemName: "forward.end.fill", disabled: isAtEnd, accessibility: "対局終了局面", action: onEnd)
            }

            Button(action: onResume) {
                Label("この局面から再開", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .accessibilityLabel("この局面から再開")
        }
    }

    private func navButton(systemName: String, disabled: Bool, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .disabled(disabled)
        .accessibilityLabel(accessibility)
    }
}
