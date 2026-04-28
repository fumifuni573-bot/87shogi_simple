import Foundation
import SwiftData

// MARK: - KifuRepository

/// KIF棋譜の永続化を担当するRepositoryクラス（Data Layer）
///
/// - SwiftData を一次ストレージとして使用
/// - 既存のファイルベース棋譜（KifStore）からの移行をサポート
/// - 将来: SyncService / KifuFetcher / ProKifuFetcher と接続予定
@MainActor
final class KifuRepository {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - CRUD

    /// 棋譜レコードを挿入して保存する
    func insert(_ record: KifuRecord) throws {
        context.insert(record)
        try context.save()
    }

    /// 全棋譜を作成日時の降順で取得する
    func fetchAll() throws -> [KifuRecord] {
        let descriptor = FetchDescriptor<KifuRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// IDで棋譜レコードを1件取得する
    func fetch(id: UUID) throws -> KifuRecord? {
        var descriptor = FetchDescriptor<KifuRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// タイトルで棋譜レコードを1件取得する
    func fetch(title: String) throws -> KifuRecord? {
        var descriptor = FetchDescriptor<KifuRecord>(
            predicate: #Predicate { $0.title == title }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 棋譜レコードを削除して保存する
    func delete(_ record: KifuRecord) throws {
        context.delete(record)
        try context.save()
    }

    /// 棋譜レコードのタイトルを変更して保存する
    func rename(_ record: KifuRecord, to newTitle: String) throws {
        record.title = newTitle
        try context.save()
    }

    /// 棋譜レコードのフォルダを変更して保存する
    func updateFolder(_ record: KifuRecord, to folderName: String) throws {
        record.folderName = folderName
        try context.save()
    }

    // MARK: - ファイルストアからの移行

    /// 既存の `.kif` ファイルをSwiftDataに取り込む（初回起動時の移行）
    ///
    /// - すでにDBに同名タイトルが存在する場合はスキップ
    /// - ファイルは削除しない（将来のエクスポート用に温存）
    func migrateFromFileStoreIfNeeded(isRunningInPreviews: Bool) {
        guard
            let directoryURL = try? KifStore.recordsDirectoryURL(isRunningInPreviews: isRunningInPreviews),
            let urls = try? KifStore.listKifURLs(in: directoryURL)
        else { return }

        let existing = (try? fetchAll()) ?? []
        let existingTitles = Set(existing.map(\.title))

        var didInsert = false

        for url in urls {
            let title = url.deletingPathExtension().lastPathComponent
            guard !existingTitles.contains(title),
                  let text = try? KifStore.readText(at: url) else { continue }

            let (moveCount, resultSummary) = KifuCodec.parseMetadata(from: text)

            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let createdAt = values?.contentModificationDate ?? Date()

            let record = KifuRecord(
                title: title,
                kifText: text,
                moveCount: moveCount,
                resultSummary: resultSummary,
                createdAt: createdAt
            )
            context.insert(record)
            didInsert = true
        }

        if didInsert {
            try? context.save()
        }
    }
}
