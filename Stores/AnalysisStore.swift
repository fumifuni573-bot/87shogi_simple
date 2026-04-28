import Foundation
import Combine

@MainActor
final class AnalysisStore: ObservableObject {
    @Published private(set) var latestResult: AnalysisResultModel?
    @Published private(set) var isAnalyzing = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastRequest: AnalysisRequestModel?

    private let service: AnalysisService
    private var analysisTask: Task<Void, Never>?

    init(service: AnalysisService? = nil) {
        self.service = service ?? StubAnalysisService()
    }

    func requestAnalysis(for snapshot: ShogiGameSnapshot) {
        cancelAnalysis()

        let request = AnalysisRequestModel(snapshot: snapshot)
        lastRequest = request
        isAnalyzing = true
        lastErrorMessage = nil

        analysisTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await service.analyze(request)
                self.latestResult = result
                self.isAnalyzing = false
            } catch {
                self.lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? "解析に失敗しました"
                self.isAnalyzing = false
            }
        }
    }

    func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        service.cancelCurrentAnalysis()
        isAnalyzing = false
    }
}
