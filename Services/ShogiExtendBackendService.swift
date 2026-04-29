import Foundation

struct ShogiExtendBackendService {
    static let storageKey = "shogiExtendBackendBaseURL"
    static let defaultBaseURLString = "http://127.0.0.1:8000"

    enum BackendError: LocalizedError {
        case invalidBaseURL
        case invalidResponse
        case unexpectedStatus(Int)

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL:
                return "バックエンドURLが不正です"
            case .invalidResponse:
                return "バックエンド応答を解釈できませんでした"
            case .unexpectedStatus(let status):
                return "バックエンド通信に失敗しました (HTTP \(status))"
            }
        }
    }

    enum ScrapeMode: String, Encodable {
        case full
        case incremental
    }

    struct TrackedSourceResponse: Decodable {
        let id: String
        let username: String
        let enabled: Bool
    }

    struct ScrapeJobResponse: Decodable {
        let id: String
        let username: String
        let mode: String
        let status: String
        let requestedAt: Date?
        let startedAt: Date?
        let finishedAt: Date?
        let processedPages: Int?
        let insertedGames: Int?
        let skippedGames: Int?
        let fetchedGames: Int?
        let errorSummary: String?

        enum CodingKeys: String, CodingKey {
            case id
            case username
            case mode
            case status
            case requestedAt = "requested_at"
            case startedAt = "started_at"
            case finishedAt = "finished_at"
            case processedPages = "processed_pages"
            case insertedGames = "inserted_games"
            case skippedGames = "skipped_games"
            case fetchedGames = "fetched_games"
            case errorSummary = "error_summary"
        }

        var statusLabel: String {
            switch status {
            case "queued": return "待機中"
            case "running": return "取得中"
            case "succeeded": return "完了"
            case "failed": return "失敗"
            default: return status
            }
        }

        var summaryLine: String {
            if status == "failed", let errorSummary, !errorSummary.isEmpty {
                return errorSummary
            }
            let inserted = insertedGames ?? 0
            let skipped = skippedGames ?? 0
            let processed = processedPages ?? 0
            return "新規\(inserted)件 / スキップ\(skipped)件 / \(processed)ページ"
        }
    }

    struct KifuItemSummaryResponse: Decodable {
        let id: String
        let username: String
        let jobId: String?
        let sourceGameID: String
        let sourceGameURL: String
        let searchedPage: Int
        let scrapedAt: Date
        let matchDateTime: Date?
        let players: [String: String?]
        let result: String?

        enum CodingKeys: String, CodingKey {
            case id
            case username
            case jobId = "job_id"
            case sourceGameID = "source_game_id"
            case sourceGameURL = "source_game_url"
            case searchedPage = "searched_page"
            case scrapedAt = "scraped_at"
            case matchDateTime = "match_datetime"
            case players
            case result
        }

        var matchupLabel: String {
            let sente = players["sente"] ?? nil ?? "先手不明"
            let gote = players["gote"] ?? nil ?? "後手不明"
            return "\(sente) vs \(gote)"
        }

        var summaryLine: String {
            let resultLabel = result ?? "結果不明"
            return "\(resultLabel) / p.\(searchedPage)"
        }
    }

    private struct RegisterPayload: Encodable {
        let username: String
        let enabled: Bool
    }

    private struct JobPayload: Encodable {
        let username: String
        let mode: ScrapeMode
    }

    var baseURLString: String {
        UserDefaults.standard.string(forKey: Self.storageKey) ?? Self.defaultBaseURLString
    }

    private var session: URLSession { .shared }
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func normalizedBaseURLString(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty else {
            return nil
        }
        var normalized = components
        normalized.scheme = scheme
        return normalized.url?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func registerTrackedUser(username: String) async throws -> TrackedSourceResponse {
        let payload = RegisterPayload(username: username, enabled: true)
        return try await sendRequest(path: "/tracked-sources", method: "POST", body: payload)
    }

    func enqueueScrapeJob(username: String, mode: ScrapeMode = .incremental) async throws -> ScrapeJobResponse {
        let payload = JobPayload(username: username, mode: mode)
        return try await sendRequest(path: "/scrape-jobs", method: "POST", body: payload)
    }

    func listScrapeJobs(username: String, limit: Int = 5) async throws -> [ScrapeJobResponse] {
        guard let baseURL = URL(string: baseURLString),
              var components = URLComponents(url: baseURL.appending(path: "/scrape-jobs"), resolvingAgainstBaseURL: true) else {
            throw BackendError.invalidBaseURL
        }
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components.url else {
            throw BackendError.invalidBaseURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw BackendError.unexpectedStatus(httpResponse.statusCode)
        }
        return try decoder.decode([ScrapeJobResponse].self, from: data)
    }

    func listKifuItems(username: String, jobID: String, limit: Int = 10) async throws -> [KifuItemSummaryResponse] {
        guard let baseURL = URL(string: baseURLString),
              var components = URLComponents(url: baseURL.appending(path: "/kifu-items"), resolvingAgainstBaseURL: true) else {
            throw BackendError.invalidBaseURL
        }
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "job_id", value: jobID),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components.url else {
            throw BackendError.invalidBaseURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw BackendError.unexpectedStatus(httpResponse.statusCode)
        }
        return try decoder.decode([KifuItemSummaryResponse].self, from: data)
    }

    func deleteTrackedUser(username: String) async throws {
        guard let baseURL = URL(string: baseURLString),
              let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "/tracked-sources/\(encoded)", relativeTo: baseURL) else {
            throw BackendError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) || httpResponse.statusCode == 404 else {
            throw BackendError.unexpectedStatus(httpResponse.statusCode)
        }
    }

    private func sendRequest<Response: Decodable, Body: Encodable>(path: String, method: String, body: Body) async throws -> Response {
        guard let baseURL = URL(string: baseURLString), let url = URL(string: path, relativeTo: baseURL) else {
            throw BackendError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw BackendError.unexpectedStatus(httpResponse.statusCode)
        }
        return try decoder.decode(Response.self, from: data)
    }
}
