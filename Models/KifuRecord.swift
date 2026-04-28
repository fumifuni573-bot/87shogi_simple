import Foundation
import SwiftData

// MARK: - 同期ステータス

/// KIF棋譜のサーバー同期状態
enum KifuSyncStatus: String, Codable {
    case local    // ローカル作成のみ
    case pending  // サーバー同期待ち（将来: SyncService連携）
    case synced   // サーバー同期済み（将来: SyncService連携）
}

// MARK: - SwiftData モデル

/// KifuRepository が管理する棋譜レコード（SwiftData永続化）
@Model
final class KifuRecord {
    @Attribute(.unique) var id: UUID
    /// 表示タイトル（ファイル名由来 or ユーザー指定）
    var title: String
    /// KIF形式テキスト（`#KIF version=2.0` + 独自ペイロード。KifuCodec.encode で生成）
    var kifText: String
    /// 生 KIF/CSA テキスト（KifuFetcher / KifuParser が取得した原文。ローカル作成は nil）
    var rawKifText: String?
    /// 手数
    var moveCount: Int
    /// 結果サマリー（"先手の勝ち（詰み）" など）
    var resultSummary: String
    /// 棋譜取得元プロバイダ（rawValue 保持）
    var providerRaw: String
    /// 登録URLソース（ローカル棋譜は nil）
    var sourceURL: String?
    /// 作成日時
    var createdAt: Date
    /// 同期ステータス（rawValue 保持）
    var syncStatusRaw: String
    /// フォルダ名（"" = 未分類）
    var folderName: String

    init(
        id: UUID = UUID(),
        title: String,
        kifText: String,
        rawKifText: String? = nil,
        moveCount: Int = 0,
        resultSummary: String = "",
        provider: KifuSourceProvider = .other,
        sourceURL: String? = nil,
        createdAt: Date = Date(),
        syncStatus: KifuSyncStatus = .local,
        folderName: String = ""
    ) {
        self.id = id
        self.title = title
        self.kifText = kifText
        self.rawKifText = rawKifText
        self.moveCount = moveCount
        self.resultSummary = resultSummary
        self.providerRaw = provider.rawValue
        self.sourceURL = sourceURL
        self.createdAt = createdAt
        self.syncStatusRaw = syncStatus.rawValue
        self.folderName = folderName
    }

    var provider: KifuSourceProvider {
        KifuSourceProvider(rawValue: providerRaw) ?? .other
    }

    var syncStatus: KifuSyncStatus {
        get { KifuSyncStatus(rawValue: syncStatusRaw) ?? .local }
        set { syncStatusRaw = newValue.rawValue }
    }

    /// SavedKifFileModel（プレゼンテーション層）へ変換
    var asSavedKifFile: SavedKifFileModel {
        SavedKifFileModel(
            id: id,
            fileURL: nil,
            fileName: title,
            savedAt: createdAt,
            summary: "\(resultSummary)・\(moveCount)手",
            folderName: folderName
        )
    }
}
