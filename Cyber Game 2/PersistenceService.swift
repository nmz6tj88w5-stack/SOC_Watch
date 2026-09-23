import Foundation

/// Isolates UserDefaults access from GameEngine. JSON-encoded GameState
/// under a single versioned key, per the V1 persistence requirement.
struct PersistenceService {
    private let key = "com.socwatch.gamestate.v1"
    private let onboardingKey = "com.socwatch.onboarding.seen.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> GameState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GameState.self, from: data)
    }

    func save(_ state: GameState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    /// Kept separate from GameState — this is an install-level flag, not
    /// game progress, so it shouldn't ride along with save-game schema
    /// versioning.
    func hasSeenOnboarding() -> Bool {
        defaults.bool(forKey: onboardingKey)
    }

    func setHasSeenOnboarding(_ seen: Bool) {
        defaults.set(seen, forKey: onboardingKey)
    }
}
