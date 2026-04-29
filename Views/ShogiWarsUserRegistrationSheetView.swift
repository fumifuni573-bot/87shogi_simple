import SwiftUI

struct ShogiWarsUserRegistrationSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputUsername: String = ""
    @State private var errorMessage: String? = nil
    @State private var isRegistering = false

    let onRegister: (String) async -> ShogiWarsUserStore.AddResult

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("将棋ウォーズユーザーを登録")
                        .font(.title3.bold())
                    Text("登録した username は reload 時に backend へスクレイプ要求を送ります")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField("chubby_cat", text: $inputUsername)
                        .textInputAutocapitalization(.never)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(errorMessage != nil ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1.5)
                        )
                        .onChange(of: inputUsername) {
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
                        let result = await onRegister(inputUsername)
                        isRegistering = false
                        if result.isSuccess {
                            dismiss()
                        } else {
                            switch result {
                            case .empty:
                                errorMessage = "ユーザー名を入力してください"
                            case .invalidUsername:
                                errorMessage = "英数字、アンダースコア、ハイフンのみ使えます"
                            case .duplicate:
                                errorMessage = "このユーザーはすでに登録済みです"
                            case .backendUnavailable:
                                errorMessage = "backend に接続できませんでした"
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
                            Label("登録", systemImage: "person.badge.plus")
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
            .navigationTitle("ユーザー登録")
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