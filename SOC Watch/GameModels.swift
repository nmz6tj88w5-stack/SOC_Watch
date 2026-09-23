import Foundation

enum LayerID: String, Codable, CaseIterable {
    case edr
    case siem
    case threatIntel
}

enum UpgradeAxis: String, Codable, CaseIterable {
    case cadence
    case neutralization
    case budgetPerKill
}

struct LayerState: Codable {
    var cadenceLevel: Int = 0
    var neutralizationLevel: Int = 0
    var budgetPerKillLevel: Int = 0

    func level(for axis: UpgradeAxis) -> Int {
        switch axis {
        case .cadence: return cadenceLevel
        case .neutralization: return neutralizationLevel
        case .budgetPerKill: return budgetPerKillLevel
        }
    }

    mutating func incrementLevel(for axis: UpgradeAxis) {
        switch axis {
        case .cadence: cadenceLevel += 1
        case .neutralization: neutralizationLevel += 1
        case .budgetPerKill: budgetPerKillLevel += 1
        }
    }
}

/// Cross-session progress. In-flight wave/alert state is intentionally
/// excluded — see IncomingAlert doc comment.
struct GameState: Codable {
    var budget: Double = 0
    var currentWave: Int = 1
    var absorptionCapacity: Double
    var absorptionCapacityMax: Double
    var layers: [LayerID: LayerState]
    var totalPrestigePoints: Double = 0
    var prestigeMultiplier: Double = 1.0
    var totalPostMortems: Int = 0
    var bestWaveReached: Int = 0
    var lastActiveTimestamp: Date = Date()

    static func initial(absorptionCapacityMax: Double) -> GameState {
        var layers: [LayerID: LayerState] = [:]
        for id in LayerID.allCases { layers[id] = LayerState() }
        return GameState(
            absorptionCapacity: absorptionCapacityMax,
            absorptionCapacityMax: absorptionCapacityMax,
            layers: layers
        )
    }
}

struct BreachSummary: Equatable {
    let waveReached: Int
    let pointsEarned: Double
    let newMultiplier: Double
    let occurredAt: Date
}

/// Ephemeral, in-flight alert. Never persisted, never re-derived into a
/// stored "progress" field: spawnDate + travelDuration are immutable and
/// every consumer (engine tick, Canvas render) computes progress fresh
/// from `now`, so there is exactly one source of truth for position.
struct IncomingAlert: Identifiable, Equatable {
    let id = UUID()
    let ringAngleDegrees: Double
    let spawnDate: Date
    let travelDuration: TimeInterval
    /// Set once the alert is removed from play, either neutralized by a
    /// layer or leaked past the core. `neutralizedByLayer` distinguishes
    /// the two: nil means it leaked.
    var isResolved: Bool = false
    var resolvedAt: Date? = nil
    var neutralizedByLayer: LayerID? = nil

    var isLeak: Bool { isResolved && neutralizedByLayer == nil }

    func progress(at date: Date) -> Double {
        min(1, max(0, date.timeIntervalSince(spawnDate) / travelDuration))
    }
}

/// Ephemeral record of a layer taking a shot at a target, purely for
/// visual feedback (sensor pulse + beam in DefenseZoneView) so a tap on
/// an upgrade button — and the resulting cadence/neutralization change —
/// is actually visible on screen, not just reflected in a number. Never
/// persisted.
struct FireEvent: Identifiable {
    let id = UUID()
    let layerID: LayerID
    let firedAt: Date
    let hit: Bool
    let targetAngleDegrees: Double
}
