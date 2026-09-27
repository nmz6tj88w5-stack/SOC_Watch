import GoogleMobileAds
import UserMessagingPlatform
import UIKit

/// Wraps the Google Mobile Ads SDK for a single rewarded-ad slot (doubling
/// the offline-catch-up gain — see GameEngine.claimOfflineGainBoost()).
/// Kept out of GameEngine for the same reason as NotificationService: ad
/// presentation is a system/SDK concern, not game logic. Non-personalized
/// ads only — no App Tracking Transparency prompt, no IDFA.
@MainActor
@Observable
final class AdsService: NSObject {
    static let shared = AdsService()

    private static let rewardedAdUnitID = "ca-app-pub-3619418801985843/6188798464"

    private(set) var isReady = false
    private var rewardedAd: RewardedAd?
    private var onReward: ((Bool) -> Void)?
    private var hasStartedAds = false
    private var isRequestingConsent = false

    private override init() {}

    /// Gathers GDPR/UK consent via Google's User Messaging Platform before
    /// initializing the Mobile Ads SDK — required by Google's AdMob policies
    /// for EEA/UK/Swiss users even though we only ever request
    /// non-personalized ads. Safe to call on every foreground activation:
    /// it's a no-op once ads have successfully started, and retries the
    /// consent check if a previous attempt failed (e.g. no network).
    func requestConsentAndStart() {
        guard !hasStartedAds, !isRequestingConsent else { return }
        isRequestingConsent = true

        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        Task {
            do {
                try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            } catch {
                isRequestingConsent = false
                return
            }
            guard
                let rootViewController = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first?.keyWindow?.rootViewController
            else {
                isRequestingConsent = false
                return
            }

            try? await ConsentForm.loadAndPresentIfRequired(from: rootViewController)
            isRequestingConsent = false
            guard ConsentInformation.shared.canRequestAds, !hasStartedAds else { return }
            hasStartedAds = true
            startMobileAdsSDK()
        }
    }

    private func startMobileAdsSDK() {
        MobileAds.shared.start()
        Task { await preload() }
    }

    func preload() async {
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        do {
            let ad = try await RewardedAd.load(with: Self.rewardedAdUnitID, request: request)
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
            isReady = true
        } catch {
            isReady = false
            AnalyticsService.adLoadFailed(reason: error.localizedDescription)
        }
    }

    func show(onReward: @escaping (Bool) -> Void) {
        guard
            let rewardedAd,
            let rootViewController = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.keyWindow?.rootViewController
        else {
            onReward(false)
            return
        }
        self.onReward = onReward
        isReady = false
        rewardedAd.present(from: rootViewController) {
            self.onReward?(true)
            self.onReward = nil
        }
    }
}

extension AdsService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        rewardedAd = nil
        Task { await preload() }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        AnalyticsService.adLoadFailed(reason: error.localizedDescription)
        rewardedAd = nil
        onReward?(false)
        onReward = nil
        Task { await preload() }
    }
}
