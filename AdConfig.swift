import Foundation

enum AdConfig {
    /// 本番運用時はこのIDを実際のAdMobバナー広告ユニットIDに差し替えてください。
    /// 例: ca-app-pub-1234567890123456/1234567890
    static let productionBannerAdUnitID: String = "ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy"

    /// デバッグ時は必ずGoogle公式テストIDを使用
    static let testBannerAdUnitID: String = "ca-app-pub-3940256099942544/2934735716"

    static var bannerAdUnitID: String {
        #if DEBUG
        return testBannerAdUnitID
        #else
        return productionBannerAdUnitID
        #endif
    }
}
