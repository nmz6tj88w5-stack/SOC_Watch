import AudioToolbox

/// Tiny wrapper around iOS's built-in system sound IDs, kept out of
/// GameEngine (a UIKit/AudioToolbox concern, not game logic) and out of
/// the ambient/state-driven views (a cross-cutting side effect, not
/// layout). These numeric IDs correspond to sound files bundled with iOS
/// itself (no custom audio assets shipped with this app) — they're
/// undocumented but have been stable across iOS releases for over a
/// decade. If that ever changes, or if this needs guaranteed sounds,
/// swap these for bundled custom audio files via
/// `AudioServicesCreateSystemSoundID(url:)` instead.
enum FeedbackService {
    private static let killSoundID: SystemSoundID = 1104 // "Tock" — light click
    private static let purchaseSoundID: SystemSoundID = 1103 // "Tink" — soft confirm
    private static let breachSoundID: SystemSoundID = 1005 // attention tone

    static func playKillSound() {
        AudioServicesPlaySystemSound(killSoundID)
    }

    static func playPurchaseSound() {
        AudioServicesPlaySystemSound(purchaseSoundID)
    }

    static func playBreachSound() {
        AudioServicesPlaySystemSound(breachSoundID)
    }
}
