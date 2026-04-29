import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct SavedKifListSheetView: View {
    private struct FolderGroup: Identifiable {
        let folderName: String
        let files: [ContentView.SavedKifFile]
        var id: String { folderName }
    }

    private enum SourceFilter: String, CaseIterable, Identifiable {
        case all = "すべて"
        case shogiWars = "ウォーズ"
        case dojo81 = "81道場"
        case shogiDB2 = "ShogiDB2"
        case other = "その他"

        var id: String { rawValue }

        func matches(_ source: ContentView.RegisteredKifuSource) -> Bool {
            switch self {
            case .all: return true
            case .shogiWars: return source.provider == .shogiWars
            case .dojo81: return source.provider == .dojo81
            case .shogiDB2: return source.provider == .shogiDB2
            case .other: return source.provider == .other
            }
        }
    }

    let savedKifFiles: [ContentView.SavedKifFile]
    let registeredSources: [ContentView.RegisteredKifuSource]
    let registeredUsers: [RegisteredShogiWarsUserModel]
    let latestTrackedUserJobs: [String: ShogiExtendBackendService.ScrapeJobResponse]
    let latestTrackedUserItems: [String: [ShogiExtendBackendService.KifuItemSummaryResponse]]
    let isTrackedUserJobPolling: Bool
    let showStartScreen: Bool
    let shouldReloadOnAppear: Bool
    let leadingToolbarPlacement: ToolbarItemPlacement
    let trailingToolbarPlacement: ToolbarItemPlacement
    let accentTint: Color

    @Binding var showRenameKifAlert: Bool
    @Binding var renameTitleInput: String
    @State private var sourceFilter: SourceFilter = .all
    @State private var folderFilter: String = "__all__"

    let onSelect: (ContentView.SavedKifFile) -> Void
    let onOpenSource: (ContentView.RegisteredKifuSource) -> Void
    let onDeleteFile: (ContentView.SavedKifFile) -> Void
    let onDeleteOffsets: (IndexSet) -> Void
    let onDeleteSource: (ContentView.RegisteredKifuSource) -> Void
    let onRenameRequest: (ContentView.SavedKifFile) -> Void
    let onClose: () -> Void
    let onSaveCurrent: () -> Void
    let onImportFile: (URL) -> Void
    let onImportPastedText: (String) async -> String?
    let onMoveToFolder: (ContentView.SavedKifFile, String) -> Void
    let onRegisterURL: (String) async -> URLSourceStore.AddResult
    let onRegisterUser: (String) async -> ShogiWarsUserStore.AddResult
    let onReload: () -> Void
    let onRenameSave: () -> Void
    let onRenameCancel: () -> Void
    var isSyncing: Bool = false
    var syncProgress: Double = 0
    var syncCompletedCount: Int = 0
    var syncTotalCount: Int = 0
    var isNetworkUnavailable: Bool = false
    var hasFailedSources: Bool = false
    let onRetryFailed: () -> Void
    let onDeleteUser: (RegisteredShogiWarsUserModel) -> Void

    @State private var showURLRegistrationSheet = false
    @State private var showUserRegistrationSheet = false
    @State private var showBackendSettingsSheet = false
    @State private var showFileImporter = false
    @State private var showPasteKifSheet = false
    @State private var pastedKifText = ""
    @FocusState private var isPasteEditorFocused: Bool
    @State private var showPasteboardReadAlert = false
    @State private var pasteboardReadMessage = ""
    @State private var showPasteImportAlert = false
    @State private var pasteImportMessage = ""
    @State private var isImportingPastedKif = false
    @State private var moveFolderTarget: ContentView.SavedKifFile? = nil
    @State private var showMoveFolderSheet = false
    @State private var selectedMoveFolder = ""
    @State private var showNewFolderAlert = false
    @State private var newFolderInput = ""
    @AppStorage("savedKifFolderCatalogV1") private var folderCatalogRaw = "[]"
    @State private var folderCatalog: [String] = []

    private let allFoldersFilterValue = "__all__"
    private let uncategorizedFilterValue = "__uncategorized__"
    private let moveUncategorizedValue = "__move_uncategorized__"

    private var trimmedPastedKifText: String {
        pastedKifText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var estimatedPasteImportSeconds: ClosedRange<Int>? {
        let text = trimmedPastedKifText
        guard !text.isEmpty else { return nil }

        let lineCount = text.split(separator: "\n", omittingEmptySubsequences: false).count
        let moveLikeLines = text.split(separator: "\n").filter {
            let line = $0.trimmingCharacters(in: .whitespaces)
            return line.first?.isNumber == true || line.hasPrefix("+") || line.hasPrefix("-")
        }.count
        let charCount = text.count

        let complexityScore = max(lineCount / 40, 0) + max(moveLikeLines / 60, 0) + max(charCount / 4000, 0)
        switch complexityScore {
        case ..<1:
            return 1...2
        case 1:
            return 2...4
        case 2:
            return 4...7
        default:
            return 7...12
        }
    }

    private var estimatedPasteImportLabel: String {
        guard let range = estimatedPasteImportSeconds else {
            return ""
        }
        if range.lowerBound == range.upperBound {
            return "約\(range.lowerBound)秒"
        }
        return "約\(range.lowerBound)〜\(range.upperBound)秒"
    }

    private var filteredSources: [ContentView.RegisteredKifuSource] {
        registeredSources.filter { sourceFilter.matches($0) }
    }

    /// 存在する命名フォルダ名（アルファベット順）
    private var namedFolders: [String] {
        let usedNames = savedKifFiles.compactMap { $0.folderName.isEmpty ? nil : $0.folderName }
        return Array(Set(usedNames + folderCatalog)).sorted()
    }

    private var folderFilterOptions: [String] {
        var options: [String] = [allFoldersFilterValue]
        options.append(contentsOf: namedFolders)
        if savedKifFiles.contains(where: { $0.folderName.isEmpty }) {
            options.append(uncategorizedFilterValue)
        }
        return options
    }

    private var filteredSavedKifFiles: [ContentView.SavedKifFile] {
        switch folderFilter {
        case allFoldersFilterValue:
            return savedKifFiles
        case uncategorizedFilterValue:
            return savedKifFiles.filter { $0.folderName.isEmpty }
        default:
            return savedKifFiles.filter { $0.folderName == folderFilter }
        }
    }

    /// フォルダ分けがあるか（少なくとも1つの命名フォルダがある）
    private var hasFolders: Bool {
        filteredSavedKifFiles.contains { !$0.folderName.isEmpty }
    }

    /// グループ表示用：命名フォルダが先、未分類が後
    private var groupedFolderNames: [String] {
        var result = Array(Set(filteredSavedKifFiles.compactMap { $0.folderName.isEmpty ? nil : $0.folderName })).sorted()
        if filteredSavedKifFiles.contains(where: { $0.folderName.isEmpty }) {
            result.append("")
        }
        return result
    }

    private var groupedSavedKifFiles: [FolderGroup] {
        groupedFolderNames.map { name in
            FolderGroup(folderName: name, files: files(inFolder: name))
        }
    }

    private func files(inFolder folder: String) -> [ContentView.SavedKifFile] {
        filteredSavedKifFiles.filter { $0.folderName == folder }
    }

    private func folderFilterLabel(for value: String) -> String {
        switch value {
        case allFoldersFilterValue:
            return "すべてのフォルダ"
        case uncategorizedFilterValue:
            return "未分類"
        default:
            return value
        }
    }

    private func folderCount(for value: String) -> Int {
        switch value {
        case allFoldersFilterValue:
            return savedKifFiles.count
        case uncategorizedFilterValue:
            return savedKifFiles.filter { $0.folderName.isEmpty }.count
        default:
            return savedKifFiles.filter { $0.folderName == value }.count
        }
    }

    private func folderIcon(for value: String) -> String {
        switch value {
        case allFoldersFilterValue:
            return "tray.full"
        case uncategorizedFilterValue:
            return "tray"
        default:
            return "folder"
        }
    }

    private func loadFolderCatalog() {
        guard let data = folderCatalogRaw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            folderCatalog = []
            return
        }
        folderCatalog = decoded
    }

    private func saveFolderCatalog() {
        let normalized = Array(Set(folderCatalog)).sorted()
        folderCatalog = normalized
        if let data = try? JSONEncoder().encode(normalized),
           let raw = String(data: data, encoding: .utf8) {
            folderCatalogRaw = raw
        }
    }

    private func addFolderToCatalog(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !folderCatalog.contains(trimmed) {
            folderCatalog.append(trimmed)
            saveFolderCatalog()
        }
    }

    private func folderSectionTitle(_ folderName: String) -> String {
        folderName.isEmpty ? "未分類" : folderName
    }

    private func displayFolderName(_ folderName: String) -> String {
        folderName.isEmpty ? "未分類" : folderName
    }

    private var moveFolderOptions: [String] {
        var options = namedFolders
        options.append(moveUncategorizedValue)
        return options
    }

    private func moveFolderLabel(for value: String) -> String {
        value == moveUncategorizedValue ? "未分類" : value
    }

    private func folderName(fromMoveSelection value: String) -> String {
        value == moveUncategorizedValue ? "" : value
    }

    @ViewBuilder
    private var folderTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(folderFilterOptions, id: \.self) { value in
                    Button {
                        folderFilter = value
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: folderIcon(for: value))
                                .font(.caption)
                            Text(folderFilterLabel(for: value))
                                .font(.subheadline)
                            Text("\(folderCount(for: value))")
                                .font(.caption2.monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundStyle(folderFilter == value ? .white : .primary)
                        .background(folderFilter == value ? accentTint : Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var savedKifSectionsView: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("フォルダーを選ぶと、下に棋譜一覧を表示します")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                folderTabsView
            }
        }

        if filteredSavedKifFiles.isEmpty {
            Section("保存棋譜") {
                ContentUnavailableView(
                    "該当する棋譜がありません",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("フォルダフィルターを変更してください")
                )
            }
        } else if hasFolders {
            ForEach(groupedSavedKifFiles, id: \.id) { group in
                Section(folderSectionTitle(group.folderName)) {
                    ForEach(group.files, id: \.listIdentity) { file in
                        kifFileRow(file)
                    }
                    .onDelete { offsets in
                        // このセクション内でのみ削除を処理
                        for index in offsets.sorted(by: >) {
                            let filesInFolder = files(inFolder: group.folderName)
                            guard filesInFolder.indices.contains(index) else { continue }
                            onDeleteFile(filesInFolder[index])
                        }
                    }
                }
            }
        } else {
            Section("保存棋譜") {
                ForEach(filteredSavedKifFiles, id: \.listIdentity) { file in
                    kifFileRow(file)
                }
                .onDelete { offsets in
                    for index in offsets.sorted(by: >) {
                        guard filteredSavedKifFiles.indices.contains(index) else { continue }
                        onDeleteFile(filteredSavedKifFiles[index])
                    }
                }
            }
        }
    }

    private var moveFolderSheetView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if let target = moveFolderTarget {
                    Text("対象: \(target.fileName)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Picker("移動先フォルダ", selection: $selectedMoveFolder) {
                    ForEach(moveFolderOptions, id: \.self) { value in
                        Text(moveFolderLabel(for: value)).tag(value)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    newFolderInput = ""
                    showNewFolderAlert = true
                } label: {
                    Label("新規フォルダを作成", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("移動先フォルダを選択")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showMoveFolderSheet = false
                        moveFolderTarget = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("移動") {
                        guard let target = moveFolderTarget else { return }
                        let destination = folderName(fromMoveSelection: selectedMoveFolder)
                        onMoveToFolder(target, destination)
                        folderFilter = destination.isEmpty ? uncategorizedFilterValue : destination
                        showMoveFolderSheet = false
                        moveFolderTarget = nil
                    }
                    .disabled({
                        guard let target = moveFolderTarget else { return true }
                        return folderName(fromMoveSelection: selectedMoveFolder) == target.folderName
                    }())
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if savedKifFiles.isEmpty && registeredSources.isEmpty && registeredUsers.isEmpty {
                    ContentUnavailableView(
                        "棋譜データはまだありません",
                        systemImage: "doc.text",
                        description: Text(showStartScreen ? "URL登録または対局後のKIF保存から始められます。" : "右上の保存またはURL登録から棋譜を追加できます。")
                    )
                } else {
                    if !savedKifFiles.isEmpty {
                        savedKifSectionsView
                    }

                    if !registeredSources.isEmpty {
                        Section("登録URL") {
                            Picker("ソース", selection: $sourceFilter) {
                                ForEach(SourceFilter.allCases) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)

                            ForEach(filteredSources) { source in
                                sourceRow(source)
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    guard filteredSources.indices.contains(index) else { continue }
                                    onDeleteSource(filteredSources[index])
                                }
                            }
                        }
                    }

                    if !registeredUsers.isEmpty {
                        Section("登録ユーザー") {
                            if isTrackedUserJobPolling {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                    Text("backend のジョブ状態を更新中")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            ForEach(registeredUsers) { user in
                                trackedUserRow(user)
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    guard registeredUsers.indices.contains(index) else { continue }
                                    onDeleteUser(registeredUsers[index])
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("保存棋譜")
            .onAppear {
                loadFolderCatalog()
                if shouldReloadOnAppear {
                    onReload()
                }
                if !folderFilterOptions.contains(folderFilter) {
                    folderFilter = allFoldersFilterValue
                }
            }
            .onChange(of: folderCatalogRaw) {
                loadFolderCatalog()
                if !folderFilterOptions.contains(folderFilter) {
                    folderFilter = allFoldersFilterValue
                }
            }
            .onChange(of: savedKifFiles.map(\.listIdentity)) {
                if !folderFilterOptions.contains(folderFilter) {
                    folderFilter = allFoldersFilterValue
                }
            }
            .toolbar {
                ToolbarItem(placement: leadingToolbarPlacement) {
                    Button("閉じる", action: onClose)
                }
                ToolbarItemGroup(placement: trailingToolbarPlacement) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .accessibilityLabel("棋譜ファイルを読み込む")

                    Button {
                        pastedKifText = ""
                        showPasteKifSheet = true
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .accessibilityLabel("棋譜テキストを貼り付ける")

                    Button {
                        showURLRegistrationSheet = true
                    } label: {
                        Image(systemName: "link.badge.plus")
                    }

                    Button {
                        showUserRegistrationSheet = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }

                    Button {
                        showBackendSettingsSheet = true
                    } label: {
                        Image(systemName: "server.rack")
                    }
                    .accessibilityLabel("backend 接続設定")

                    Button {
                        moveFolderTarget = nil
                        newFolderInput = ""
                        showNewFolderAlert = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel("新規フォルダを作成")

                    if !showStartScreen {
                        Button(action: onSaveCurrent) {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                    if isSyncing {
                        // 同期中: プログレスインジケータ + n/m
                        HStack(spacing: 6) {
                            ProgressView(value: syncProgress)
                                .progressViewStyle(.circular)
                                .frame(width: 22, height: 22)
                            Text("\(syncCompletedCount)/\(max(syncTotalCount, 1))")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("同期中 \(syncCompletedCount)/\(max(syncTotalCount, 1))件")
                    } else if isNetworkUnavailable && hasFailedSources {
                        // オフライン + 失敗済みソースあり: 再試行ボタン
                        Button(action: onRetryFailed) {
                            Label("再試行", systemImage: "wifi.exclamationmark")
                                .foregroundStyle(.orange)
                        }
                        .accessibilityLabel("オフラインのため失敗した棋譜を再試行")
                    } else {
                        Button(action: onReload) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("棋譜を同期")
                    }
                }
            }
            .alert("タイトル変更", isPresented: $showRenameKifAlert) {
                TextField("タイトル", text: $renameTitleInput)
                Button("保存", action: onRenameSave)
                Button("キャンセル", role: .cancel, action: onRenameCancel)
            } message: {
                Text("棋譜のタイトルを変更します")
            }
            .alert("新規フォルダを作成", isPresented: $showNewFolderAlert) {
                TextField("フォルダ名", text: $newFolderInput)
                Button("作成") {
                    let name = newFolderInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        addFolderToCatalog(name)
                        folderFilter = name
                        if let target = moveFolderTarget {
                            onMoveToFolder(target, name)
                        }
                    }
                    newFolderInput = ""
                    moveFolderTarget = nil
                }
                Button("キャンセル", role: .cancel) {
                    newFolderInput = ""
                    moveFolderTarget = nil
                }
            } message: {
                Text("棋譜をこの新しいフォルダに移動します")
            }
            .sheet(isPresented: $showURLRegistrationSheet) {
                URLRegistrationSheetView(onRegister: onRegisterURL)
            }
            .sheet(isPresented: $showUserRegistrationSheet) {
                ShogiWarsUserRegistrationSheetView(onRegister: onRegisterUser)
            }
            .sheet(isPresented: $showBackendSettingsSheet) {
                ShogiExtendBackendSettingsSheetView()
            }
            .sheet(isPresented: $showMoveFolderSheet) {
                moveFolderSheetView
            }
            .sheet(isPresented: $showPasteKifSheet) {
                pasteKifSheetView
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: supportedImportTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let first = urls.first {
                        onImportFile(first)
                    }
                case .failure:
                    break
                }
            }
        }
    }

    private var pasteKifSheetView: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("KIF / CSA の棋譜テキストを入力または貼り付けて読み込みます")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $pastedKifText)
                        .focused($isPasteEditorFocused)
                        .frame(minHeight: 240)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    if pastedKifText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("ここに貼り付け（例: KIF/CSA テキスト）")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        pastedKifText = ""
                    } label: {
                        Label("クリア", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(pastedKifText.isEmpty)

#if canImport(UIKit)
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("ペースト", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("v", modifiers: [.command])
#endif
                }

                if let _ = estimatedPasteImportSeconds {
                    HStack(spacing: 6) {
                        Image(systemName: isImportingPastedKif ? "hourglass" : "clock")
                            .foregroundStyle(.secondary)
                        Text(
                            isImportingPastedKif
                            ? "解析中です。通常 \(estimatedPasteImportLabel) 前後かかります"
                            : "推定読み込み時間: \(estimatedPasteImportLabel)"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { @MainActor in
                        let text = trimmedPastedKifText
                        isImportingPastedKif = true
                        defer { isImportingPastedKif = false }

                        if let errorMessage = await onImportPastedText(text) {
                            pasteImportMessage = errorMessage
                            showPasteImportAlert = true
                        } else {
                            showPasteKifSheet = false
                            pastedKifText = ""
                        }
                    }
                } label: {
                    Group {
                        if isImportingPastedKif {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("読み込む", systemImage: "square.and.arrow.down.on.square")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImportingPastedKif || trimmedPastedKifText.isEmpty)
            }
            .padding()
            .navigationTitle("棋譜を貼り付け")
            .onAppear {
                DispatchQueue.main.async {
                    isPasteEditorFocused = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showPasteKifSheet = false
                    } label: {
                        Text("閉じる")
                    }
                }
            }
            .alert("クリップボードを読み込めません", isPresented: $showPasteboardReadAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(pasteboardReadMessage)
            }
            .alert("棋譜を読み込めません", isPresented: $showPasteImportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(pasteImportMessage)
            }
        }
    }

    private func pasteFromClipboard() {
#if canImport(UIKit)
        let pasteboard = UIPasteboard.general

        if let text = pasteboard.string,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pastedKifText = text
            return
        }

        if let first = pasteboard.strings?.first,
           !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pastedKifText = first
            return
        }

        let candidateTypes = [
            UTType.utf8PlainText.identifier,
            UTType.plainText.identifier,
            "public.text"
        ]

        for type in candidateTypes {
            if let data = pasteboard.data(forPasteboardType: type),
               let decoded = decodeImportedKifuText(from: data),
               !decoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pastedKifText = decoded
                return
            }
        }

        if let url = pasteboard.url,
           url.isFileURL,
           let data = try? Data(contentsOf: url),
           let decoded = decodeImportedKifuText(from: data),
           !decoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pastedKifText = decoded
            return
        }

        pasteboardReadMessage = "テキストが見つかりませんでした。コピー元の形式がテキストか確認してください。"
        showPasteboardReadAlert = true
#endif
    }

    private func decodeImportedKifuText(from data: Data) -> String? {
        let encodings: [String.Encoding] = [.utf8, .shiftJIS, .japaneseEUC, .iso2022JP]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        return nil
    }

    @ViewBuilder
    private func kifFileRow(_ file: ContentView.SavedKifFile) -> some View {
        Button {
            onSelect(file)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(file.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.caption2)
                    Text(displayFolderName(file.folderName))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                Text(file.savedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onRenameRequest(file)
            } label: {
                Label("名前変更", systemImage: "pencil")
            }
            .tint(accentTint)

            Button(role: .destructive) {
                onDeleteFile(file)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                moveFolderTarget = file
                let current = file.folderName.isEmpty ? moveUncategorizedValue : file.folderName
                selectedMoveFolder = moveFolderOptions.contains(current)
                    ? current
                    : (moveFolderOptions.first ?? moveUncategorizedValue)
                showMoveFolderSheet = true
            } label: {
                Label("フォルダ移動", systemImage: "folder")
            }
            .tint(.indigo)
        }
    }

    @ViewBuilder
    private func sourceRow(_ source: ContentView.RegisteredKifuSource) -> some View {
        Button {
            onOpenSource(source)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(source.provider.label)
                        .font(.caption.bold())
                        .foregroundStyle(accentTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentTint.opacity(0.12))
                        .clipShape(Capsule())
                    Text(source.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(source.urlString)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(source.hostLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDeleteSource(source)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func trackedUserRow(_ user: RegisteredShogiWarsUserModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("ウォーズユーザー")
                    .font(.caption.bold())
                    .foregroundStyle(accentTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accentTint.opacity(0.12))
                    .clipShape(Capsule())
                Text(user.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(user.username)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(user.searchURLString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let latestJob = latestTrackedUserJobs[user.username] {
                Divider()
                    .padding(.vertical, 2)

                HStack(spacing: 8) {
                    Text(latestJob.statusLabel)
                        .font(.caption.bold())
                        .foregroundStyle(jobStatusColor(for: latestJob.status))
                    if let requestedAt = latestJob.requestedAt {
                        Text(requestedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(latestJob.summaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let importedItems = latestTrackedUserItems[user.username], !importedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("取り込み結果")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        ForEach(importedItems.prefix(5), id: \.id) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.matchupLabel)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(item.summaryLine)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(item.sourceGameURL)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("まだ backend ジョブ履歴はありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDeleteUser(user)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private func jobStatusColor(for status: String) -> Color {
        switch status {
        case "queued":
            return .orange
        case "running":
            return accentTint
        case "succeeded":
            return .green
        case "failed":
            return .red
        default:
            return .secondary
        }
    }

    private var supportedImportTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        if let kif = UTType(filenameExtension: "kif") {
            types.append(kif)
        }
        if let csa = UTType(filenameExtension: "csa") {
            types.append(csa)
        }
        return types
    }
}
