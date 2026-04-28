import Foundation
import SwiftData

// MARK: - BackgroundKifuActor
//
// バックグラウンドスレッドで SwiftData 操作を行うための @ModelActor。
// KifuRepository（@MainActor）は UI 起動操作専用。
// こちらは Item 9 の SyncService / KifuFetcher から使用する。
//
// Usage example (Item 9):
//   let actor = BackgroundKifuActor(modelContainer: appContainer)
//   Task.detached {
//       let records = try await actor.fetchAll()
//       // ... sync / parse in background ...
//   }

@ModelActor
actor BackgroundKifuActor {

    // MARK: - CRUD

    func insert(_ record: KifuRecord) throws {
        modelContext.insert(record)
        try modelContext.save()
    }

    func fetchAll() throws -> [KifuRecord] {
        let descriptor = FetchDescriptor<KifuRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> KifuRecord? {
        var descriptor = FetchDescriptor<KifuRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func delete(_ record: KifuRecord) throws {
        modelContext.delete(record)
        try modelContext.save()
    }

    func rename(_ record: KifuRecord, to newTitle: String) throws {
        record.title = newTitle
        try modelContext.save()
    }

    // MARK: - Bulk upsert（SyncService 用）

    /// 棋譜テキストとメタデータを渡してアップサート
    ///
    /// 重複判定ルール:
    /// - `sourceURL` が指定されている場合 → 同一URLが既存なら **スキップ**（URLを一意キーとして扱う）
    /// - `sourceURL` が nil の場合 → `title` が一致する既存レコードがあれば **スキップ**
    func upsert(
        title: String,
        kifText: String,
        rawKifText: String? = nil,
        moveCount: Int,
        resultSummary: String,
        provider: KifuSourceProvider = .other,
        sourceURL: String? = nil,
        createdAt: Date = Date()
    ) throws -> Bool {
        if let url = sourceURL {
            // sourceURL が同じレコードが既にあればスキップ（URL を一意キーとして使用）
            let existingByURL = (try? fetchAll())?.first { $0.sourceURL == url }
            if existingByURL != nil { return false }
        } else {
            // sourceURL がない場合は title で重複判定（ローカル作成棋譜との互換性維持）
            let existingByTitle = (try? fetchAll())?.first { $0.title == title }
            if existingByTitle != nil { return false }
        }

        let record = KifuRecord(
            title: title,
            kifText: kifText,
            rawKifText: rawKifText,
            moveCount: moveCount,
            resultSummary: resultSummary,
            provider: provider,
            sourceURL: sourceURL,
            createdAt: createdAt
        )
        modelContext.insert(record)
        try modelContext.save()
        return true
    }
}
