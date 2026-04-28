import Foundation

// MARK: - KifuImporter
//
// KifuFetcher → KifuParser → BackgroundKifuActor のパイプラインを提供する。
// 登録URLソースからの棋譜取得・解析・DB保存を一括して処理する。

enum KifuImporter {

    // MARK: - Types

    struct ImportResult {
        let record: PersistedShogiGameRecord
        let title: String
        let playerSente: String
        let playerGote: String
        let resultSummary: String
        let rawText: String
    }

    struct SaveResult {
        let importResult: ImportResult
        let didInsert: Bool
    }

    enum ImportError: Error, LocalizedError {
        case fetchFailed(Error)
        case parseFailed(Error)
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let e): return "取得エラー: \(e.localizedDescription)"
            case .parseFailed(let e): return "解析エラー: \(e.localizedDescription)"
            case .saveFailed(let e):  return "保存エラー: \(e.localizedDescription)"
            }
        }
    }

    static func userFacingMessage(for error: Error) -> String {
        if let importError = error as? ImportError {
            switch importError {
            case .fetchFailed(let underlying):
                if let fetchError = underlying as? KifuFetchError {
                    switch fetchError {
                    case .invalidURL:
                        return "URLが不正です"
                    case .httpError(let code):
                        return "サーバーエラー（HTTP \(code)）"
                    case .noData:
                        return "棋譜データが見つかりません"
                    case .decodingFailed:
                        return "文字コードの判定に失敗しました"
                    case .networkUnavailable:
                        return "ネットワークに接続できません（オフライン）"
                    case .maxRetriesExceeded:
                        return "再試行しても取得できませんでした"
                    }
                }
                return "棋譜の取得に失敗しました"
            case .parseFailed:
                return "棋譜の解析に失敗しました"
            case .saveFailed:
                return "棋譜の保存に失敗しました"
            }
        }
        return "処理に失敗しました"
    }

    // MARK: - Fetch & Parse Only

    /// URLから棋譜を取得・解析してImportResultを返す（DB保存なし）
    static func fetch(from urlString: String) async throws -> ImportResult {
        let text: String
        do {
            text = try await KifuFetcher.fetchText(from: urlString)
        } catch {
            throw ImportError.fetchFailed(error)
        }

        let parsed: KifuParser.ParseResult
        do {
            parsed = try KifuParser.parse(text: text, includeHistory: false)
        } catch {
            throw ImportError.parseFailed(error)
        }

        let moveCount = parsed.record.snapshot.moveRecords.count
        let title = await MainActor.run {
            KifuCodec.fileName(for: parsed.record.savedAt, moveCount: moveCount)
        }

        return ImportResult(
            record:        parsed.record,
            title:         title,
            playerSente:   parsed.playerSente,
            playerGote:    parsed.playerGote,
            resultSummary: parsed.resultSummary,
            rawText:       text
        )
    }

    // MARK: - Fetch, Parse & Save

    /// URLから棋譜を取得・解析し、BackgroundKifuActorを通じてDBに保存する
    ///
    /// - 同名タイトルが既にDB内にある場合はスキップ（upsertのduplicateスキップ動作）
    static func fetchAndSave(
        from urlString: String,
        provider: KifuSourceProvider,
        backgroundActor: BackgroundKifuActor
    ) async throws -> SaveResult {

        let result = try await fetch(from: urlString)
        let kifText = await MainActor.run {
            KifuCodec.encode(result.record)
        }

        do {
            let didInsert = try await backgroundActor.upsert(
                title:         result.title,
                kifText:       kifText,
                rawKifText:    result.rawText,
                moveCount:     result.record.snapshot.moveRecords.count,
                resultSummary: result.resultSummary,
                provider:      provider,
                sourceURL:     urlString,
                createdAt:     result.record.savedAt
            )
            return SaveResult(importResult: result, didInsert: didInsert)
        } catch {
            throw ImportError.saveFailed(error)
        }
    }
}
