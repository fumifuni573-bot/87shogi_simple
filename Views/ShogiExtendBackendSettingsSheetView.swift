import SwiftUI

struct ShogiExtendBackendSettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ShogiExtendBackendService.storageKey) private var storedBaseURL = ShogiExtendBackendService.defaultBaseURLString
    @State private var inputBaseURL = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("backend 接続設定")
                        .font(.title3.bold())
                    Text("将棋ウォーズ username 同期で使う backend の base URL を設定します")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField("http://127.0.0.1:8000", text: $inputBaseURL)
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(errorMessage != nil ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1.5)
                        )
                        .onChange(of: inputBaseURL) {
                            errorMessage = nil
                        }

                    if let message = errorMessage {
                        Label(message, systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("現在の URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(storedBaseURL)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }

                Button {
                    if let normalized = ShogiExtendBackendService.normalizedBaseURLString(from: inputBaseURL) {
                        storedBaseURL = normalized
                        dismiss()
                    } else {
                        errorMessage = "http または https の有効な URL を入力してください"
                    }
                } label: {
                    Label("保存", systemImage: "server.rack")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .cancel) {
                    storedBaseURL = ShogiExtendBackendService.defaultBaseURLString
                    inputBaseURL = ShogiExtendBackendService.defaultBaseURLString
                    errorMessage = nil
                } label: {
                    Label("デフォルトに戻す", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("backend 設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                inputBaseURL = storedBaseURL
            }
        }
    }
}