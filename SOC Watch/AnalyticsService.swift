import Foundation
import os

/// Local-only event log — no third-party SDK, no network calls, nothing
/// leaves the device. Exists purely so retention/balance questions (e.g.
/// "what wave do fresh runs actually breach at?", see knowledge/soc-watch-app
/// hypotheses.md H1) can be answered from real sessions instead of manual
/// device-interaction sampling. View events during testing via Console.app
/// or `log stream --predicate 'subsystem == "com.socwatch.app"'`, filtered
/// to category "analytics".
enum AnalyticsService {
    private static let logger = Logger(subsystem: "com.socwatch.app", category: "analytics")

    static func sessionStarted() {
        logger.log("event=session_started")
    }

    static func sessionEnded(durationSeconds: TimeInterval) {
        logger.log("event=session_ended duration_s=\(durationSeconds, format: .fixed(precision: 1), privacy: .public)")
    }

    static func waveReached(_ wave: Int) {
        logger.log("event=wave_reached wave=\(wave, privacy: .public)")
    }

    static func breach(waveReached: Int, pointsEarned: Double, newMultiplier: Double) {
        logger.log("event=breach wave=\(waveReached, privacy: .public) points_earned=\(pointsEarned, format: .fixed(precision: 1), privacy: .public) new_multiplier=\(newMultiplier, format: .fixed(precision: 3), privacy: .public)")
    }

    static func offlineGainApplied(gained: Double) {
        logger.log("event=offline_gain_applied gained=\(gained, format: .fixed(precision: 1), privacy: .public)")
    }

    static func reengagementScheduled(reason: String, delaySeconds: TimeInterval) {
        logger.log("event=reengagement_scheduled reason=\(reason, privacy: .public) delay_s=\(delaySeconds, format: .fixed(precision: 0), privacy: .public)")
    }

    static func onboardingCompleted() {
        logger.log("event=onboarding_completed")
    }

    static func adOffered() {
        logger.log("event=ad_offered")
    }

    static func adRewardGranted() {
        logger.log("event=ad_reward_granted")
    }

    static func adLoadFailed(reason: String) {
        logger.log("event=ad_load_failed reason=\(reason, privacy: .public)")
    }

    /// Logged whenever a persisted GameState fails to decode (corrupt data,
    /// or a future schema change without a migration path) — see
    /// PersistenceService.load(). Surfaces what was previously a silent
    /// `try?` failure that reset progress with no signal anywhere.
    static func saveDecodeFailed(reason: String) {
        logger.error("event=save_decode_failed reason=\(reason, privacy: .public)")
    }
}
