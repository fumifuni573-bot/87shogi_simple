import Foundation

protocol AnalysisService {
    func analyze(_ request: AnalysisRequestModel) async throws -> AnalysisResultModel
    func cancelCurrentAnalysis()
}

final class StubAnalysisService: AnalysisService {
    func analyze(_ request: AnalysisRequestModel) async throws -> AnalysisResultModel {
        // 将来: 本格エンジン連携（ローカル探索 or API）
        // 現状はUI配線確認用のダミー結果を返す。
        let sample = AnalysisLineModel(
            moves: request.snapshot.moveRecords.suffix(3) + ["▲７六歩", "△３四歩", "▲２六歩"],
            scoreCp: 0,
            depth: 1
        )
        return AnalysisResultModel(requestId: request.id, lines: [sample])
    }

    func cancelCurrentAnalysis() {
        // 将来: エンジン探索キャンセル処理
    }
}
