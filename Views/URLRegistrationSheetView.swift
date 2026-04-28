import SwiftUI

struct URLRegistrationSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputURL: String = ""
    @State private var errorMessage: String? = nil
    @State private var isRegistering = false

    let onRegister: (String) async -> URLSourceStore.AddResult

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("棋譜取得URLを登録")
                        .font(.title3.bold())
                    Text("ウォーズ/81道場/ShogiDB2 などのURLを登録できます")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField("https://...", text: $inputURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(errorMessage != nil ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1.5)
                        )
                        .onChange(of: inputURL) {
                            errorMessage = nil
                        }

                    if let msg = errorMessage {
                        Label(msg, systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: errorMessage)

                Button {
                    Task { @MainActor in
                        isRegistering = true
                        let result = await onRegister(inputURL)
                        isRegistering = false
                        if result.isSuccess {
                            dismiss()
                        } else {
                            switch result {
                            case .empty:
                                errorMessage = "URLを入力してください"
                            case .invalidFormat:
                                errorMessage = "有効なURLを入力してください"
                            case .duplicate:
                                errorMessage = "このURLはすでに登録済みです"
                            case .unsupportedProvider:
                                errorMessage = "将棋ウォーズのURLを入力してください"
                            case .added:
                                break
                            }
                        }
                    }
                } label: {
                    Group {
                        if isRegistering {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        } else {
                            Label("登録", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRegistering)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("URL登録")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}
