import Foundation
import Combine

// MARK: - SyncService
//
// 全登録URLソースの棋譜を一括フェッチ・保存する同期サービス。
// @MainActor で UI 更新（isSyncing / progress）を直接書き込める。
// 実際のネット通信と DB 書き込みは Task 内で非同期実行する。

@MainActor
final class SyncService: ObservableObject {

    // MARK: - State

    @Published private(set) var isSyncing = false
    @Published private(set) var syncProgress: Double = 0   // 0.0 〜 1.0
    @Published private(set) var syncCompletedCount: Int = 0
    @Published private(set) var syncTotalCount: Int = 0
    @Published private(set) var lastResult: SyncResult? = nil
    /// 前回の syncAll で失敗したソース一覧（retryFailed で再試行用）
    @Published private(set) var failedSources: [RegisteredKifuSourceModel] = []
    /// ネットワーク未接続状態かどうか
    @Published private(set) var isNetworkUnavailable = false

    // MARK: - Types

    struct SyncResult {
        let importedCount: Int
        let skippedCount: Int
        let failedCount: Int
        let errors: [String]

        var summary: String {
            if failedCount == 0 && importedCount == 0 {
                return "新着棋譜なし（\(skippedCount)件スキップ）"
            }
            var parts: [String] = []
            if importedCount > 0 { parts.append("\(importedCount)件取得") }
            if skippedCount  > 0 { parts.append("\(skippedCount)件スキップ") }
            if failedCount   > 0 { parts.append("\(failedCount)件失敗") }
            return parts.joined(separator: " / ")
        }
    }

    // MARK: - Sync

    /// 全登録ソースを並列フェッチして BackgroundKifuActor でDB保存する
    func syncAll(
        sources: [RegisteredKifuSourceModel],
        backgroundActor: BackgroundKifuActor
    ) async {
        guard !isSyncing, !sources.isEmpty else { return }
        isSyncing    = true
        syncProgress = 0
        syncCompletedCount = 0
        syncTotalCount = sources.count
        defer {
            isSyncing = false
        }

        var imported = 0
        var skipped  = 0
        var failed   = 0
        var errors:  [String] = []
        var newFailedSources: [RegisteredKifuSourceModel] = []
        var networkDown = false
        var completedCount = 0

        // 最大 3 個の並列タスク
        let maxConcurrentTasks = 3
        
        await withTaskGroup(of: (index: Int, result: Result<(source: RegisteredKifuSourceModel, saveResult: KifuImporter.SaveResult), Error>).self) { group in
            // 最初のバッチを投入
            for i in 0..<min(maxConcurrentTasks, sources.count) {
                group.addTask {
                    let source = sources[i]
                    do {
                        let saveResult = try await KifuImporter.fetchAndSave(
                            from:            source.urlString,
                            provider:        source.provider,
                            backgroundActor: backgroundActor
                        )
                        return (i, .success((source: source, saveResult: saveResult)))
                    } catch {
                        return (i, .failure(error))
                    }
                }
            }
            
            // 完了したタスクから次の URL を投入
            var nextIndex = maxConcurrentTasks
            for await (index, result) in group {
                completedCount += 1
                syncProgress = Double(completedCount) / Double(sources.count)
                syncCompletedCount = completedCount
                
                let source = sources[index]
                switch result {
                case .success(let payload):
                    if payload.saveResult.didInsert {
                        imported += 1
                    } else {
                        skipped += 1
                    }
                case .failure(let error):
                    failed += 1
                    if case KifuFetchError.networkUnavailable = error {
                        networkDown = true
                    } else if case let KifuImporter.ImportError.fetchFailed(underlying) = error,
                              case KifuFetchError.networkUnavailable = underlying {
                        networkDown = true
                    }
                    newFailedSources.append(source)
                    errors.append("[\(source.hostLabel)] \(KifuImporter.userFacingMessage(for: error))")
                }
                
                // 次の URL を投入
                if nextIndex < sources.count {
                    group.addTask {
                        let source = sources[nextIndex]
                        do {
                            let saveResult = try await KifuImporter.fetchAndSave(
                                from:            source.urlString,
                                provider:        source.provider,
                                backgroundActor: backgroundActor
                            )
                            return (nextIndex, .success((source: source, saveResult: saveResult)))
                        } catch {
                            return (nextIndex, .failure(error))
                        }
                    }
                    nextIndex += 1
                }
            }
        }

        lastResult = SyncResult(
            importedCount: imported,
            skippedCount:  skipped,
            failedCount:   failed,
            errors:        errors
        )
        failedSources = newFailedSources
        isNetworkUnavailable = networkDown
    }

    /// 前回失敗したソースのみを再試行する
    func retryFailed(
        backgroundActor: BackgroundKifuActor
    ) async {
        guard !failedSources.isEmpty, !isSyncing else { return }
        let toRetry = failedSources
        await syncAll(sources: toRetry, backgroundActor: backgroundActor)
    }

    /// 単一ソースをフェッチ（ビューア表示用）。DB保存は行わない。
    func fetchOnly(
        source: RegisteredKifuSourceModel
    ) async throws -> KifuImporter.ImportResult {
        try await KifuImporter.fetch(from: source.urlString)
    }
}
