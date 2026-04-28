import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

struct BannerAdContainerView: View {
    let adUnitID: String

    private var isConfigured: Bool {
        !adUnitID.isEmpty && !adUnitID.contains("xxxxxxxx") && !adUnitID.contains("yyyyyyyyyy")
    }

    var body: some View {
        guard isConfigured else {
            return AnyView(EmptyView())
        }

        #if canImport(GoogleMobileAds) && canImport(UIKit)
        return AnyView(
            GeometryReader { proxy in
                let width = max(proxy.size.width, 320)
                let size = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
                BannerAdRepresentable(adUnitID: adUnitID, adSize: size)
                    .frame(width: width, height: size.size.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 60)
            .background(.ultraThinMaterial)
        )
        #else
        return AnyView(EmptyView())
        #endif
    }
}

#if canImport(GoogleMobileAds) && canImport(UIKit)
private struct BannerAdRepresentable: UIViewRepresentable {
    let adUnitID: String
    let adSize: GADAdSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> GADBannerView {
        let view = GADBannerView(adSize: adSize)
        view.adUnitID = adUnitID
        view.delegate = context.coordinator
        view.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController

        let request = GADRequest()
        view.load(request)
        return view
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        if !GADAdSizeEqualToSize(uiView.adSize, adSize) {
            uiView.adSize = adSize
            let request = GADRequest()
            uiView.load(request)
        }
    }

    final class Coordinator: NSObject, GADBannerViewDelegate {
    }
}
#endif
