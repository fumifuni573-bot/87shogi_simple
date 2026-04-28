import Foundation

// MARK: - KifuFetchError

enum KifuFetchError: Error, LocalizedError {
    case invalidURL
    case httpError(Int)
    case noData
    case decodingFailed
    /// ネットワーク接続なし or 接続失敗
    case networkUnavailable
    /// 指定回数リトライしても全て失敗
    case maxRetriesExceeded(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:                   return "URLが不正です"
        case .httpError(let c):             return "HTTPエラー \(c)"
        case .noData:                       return "データが空です"
        case .decodingFailed:               return "テキストのデコードに失敗しました"
        case .networkUnavailable:           return "ネットワークに接続できません"
        case .maxRetriesExceeded:           return "再試行しても取得できませんでした"
        }
    }
}

// MARK: - KifuFetcher

/// 登録URLから棋譜テキストをダウンロードする
///
/// - 単純なHTTP GETのみを行う
/// - Shift-JIS / UTF-8 / EUC-JP / ISO-2022-JP の自動判定付き
/// - タイムアウト: リクエスト 15 秒 / リソース全体 30 秒
/// - ネットワークエラー時は最大3回まで指数バックオフリトライ
/// - 4xxクライアントエラー・不正URL・デコード失敗はリトライしない
enum KifuFetcher {

    /// リトライ間の待機時間の基尺（秒）、4xx・文字コードエラーはリトライしない
    nonisolated static let defaultMaxRetries: Int = 2
    nonisolated static let retryBaseDelay: TimeInterval = 1.0

    nonisolated private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    /// 文字列URLからテキストを取得する（失敗時は指定回数まで自動リトライ）
    nonisolated static func fetchText(from urlString: String, maxRetries: Int = defaultMaxRetries) async throws -> String {
        guard let url = URL(string: urlString) else { throw KifuFetchError.invalidURL }
        return try await fetchText(from: url, maxRetries: maxRetries)
    }

    /// URLオブジェクトからテキストを取得する（失敗時は指定回数まで自動リトライ）
    nonisolated static func fetchText(from url: URL, maxRetries: Int = defaultMaxRetries) async throws -> String {
        var lastError: Error = KifuFetchError.noData
        let maxAttempts = max(1, maxRetries + 1)

        for attempt in 0..<maxAttempts {
            // 初回以外は指数バックオフで待機〈1秒・2秒・…
            if attempt > 0 {
                let delay = retryBaseDelay * pow(2.0, Double(attempt - 1))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            do {
                return try await performFetch(from: url)
            } catch let error as KifuFetchError {
                switch error {
                case .invalidURL, .noData, .decodingFailed:
                    throw error  // リトライ不可
                case .httpError(let code):
                    if (400..<500).contains(code) { throw error }  // 4xx はリトライ不可
                    lastError = error
                case .networkUnavailable:
                    throw error  // オフラインは即座エラー
                case .maxRetriesExceeded:
                    lastError = error
                }
            } catch let urlError as URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                    throw KifuFetchError.networkUnavailable
                default:
                    lastError = urlError
                }
            } catch {
                lastError = error
            }
        }

        throw KifuFetchError.maxRetriesExceeded(underlying: lastError)
    }

    // MARK: - Private

    nonisolated private static func performFetch(from url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw KifuFetchError.httpError(http.statusCode)
        }

        guard !data.isEmpty else { throw KifuFetchError.noData }

        // 自動エンコード判定: UTF-8 → Shift-JIS → EUC-JP → ISO-2022-JP
        for encoding in [String.Encoding.utf8, .shiftJIS, .japaneseEUC, .iso2022JP] {
            if let text = String(data: data, encoding: encoding) {
                return normalizeFetchedText(text)
            }
        }
        throw KifuFetchError.decodingFailed
    }

    nonisolated private static func normalizeFetchedText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard looksLikeHTML(trimmed) else {
            return text
        }

        if let extracted = extractKifuLikeText(fromHTML: trimmed) {
            return extracted
        }
        return text
    }

    nonisolated private static func looksLikeHTML(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("<html") || lower.contains("<!doctype html") || lower.contains("<body")
    }

    nonisolated private static func extractKifuLikeText(fromHTML html: String) -> String? {
        let patterns = [
            #"(?is)<pre[^>]*>(.*?)</pre>"#,
            #"(?is)<textarea[^>]*>(.*?)</textarea>"#,
            #"(?is)<code[^>]*>(.*?)</code>"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
            let matches = regex.matches(in: html, options: [], range: nsRange)
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let range = Range(match.range(at: 1), in: html) else { continue }
                let raw = String(html[range])
                let decoded = decodeHTMLEntities(raw)
                let cleaned = stripHTMLTags(decoded).trimmingCharacters(in: .whitespacesAndNewlines)
                if looksLikeKifuOrCSA(cleaned) {
                    return cleaned
                }
            }
        }

        // 最後のフォールバック: タグを除去した全体本文から判定
        let fallback = stripHTMLTags(decodeHTMLEntities(html)).trimmingCharacters(in: .whitespacesAndNewlines)
        if looksLikeKifuOrCSA(fallback) {
            return fallback
        }

        return nil
    }

    nonisolated private static func stripHTMLTags(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(?is)<[^>]+>"#) else {
            return text
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let replaced = regex.stringByReplacingMatches(in: text, options: [], range: nsRange, withTemplate: "\n")
        return replaced
    }

    nonisolated private static func decodeHTMLEntities(_ text: String) -> String {
        var decoded = text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")

        if let numericEntityRegex = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
            let nsRange = NSRange(decoded.startIndex..<decoded.endIndex, in: decoded)
            let matches = numericEntityRegex.matches(in: decoded, options: [], range: nsRange).reversed()
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let entityRange = Range(match.range(at: 0), in: decoded),
                      let valueRange = Range(match.range(at: 1), in: decoded),
                      let scalarValue = Int(decoded[valueRange]),
                      let scalar = UnicodeScalar(scalarValue) else { continue }
                decoded.replaceSubrange(entityRange, with: String(Character(scalar)))
            }
        }

        return decoded
    }

    nonisolated private static func looksLikeKifuOrCSA(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }

        if normalized.hasPrefix("V2") || normalized.hasPrefix("V2.2") {
            return true
        }
        if normalized.contains("手数----指手") {
            return true
        }

        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: true)
        let numberedMoveLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.first?.isNumber == true
        }
        if numberedMoveLines.count >= 3 {
            return true
        }

        return normalized.contains("先手") && normalized.contains("後手") && !numberedMoveLines.isEmpty
    }
}
