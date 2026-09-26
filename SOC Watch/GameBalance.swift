import Foundation

/// Numeric tuning only — no copy, no color. Lives in a bundled JSON
/// resource (rather than compiled into GameEngine.swift) specifically so
/// balance can be retuned by swapping this file in a new build without
/// touching Swift code, and so a future remote-config fetch only has to
/// replace `loadBundled()`'s data source, not any call site.
struct GameBalance: Codable {
    // Spawn / wave difficulty
    let baseAlertCount: Double
    let alertCountGrowthPerWave: Double
    let majorIncidentVolumeMultiplier: Double
    let baseSpawnInterval: TimeInterval
    let spawnIntervalDecay: Double
    let minSpawnInterval: TimeInterval
    let majorIncidentSpawnIntervalFactor: Double
    let baseTravelDuration: TimeInterval
    let travelDurationDecay: Double
    let minTravelDuration: TimeInterval

    // Layers
    let baseFireInterval: TimeInterval
    let fireIntervalDecayPerLevel: Double
    let minFireInterval: TimeInterval
    let baseNeutralizationChance: Double
    let neutralizationChancePerLevel: Double
    let maxNeutralizationChance: Double
    let baseBudgetPerKill: Double
    let budgetPerKillGrowthPerLevel: Double

    // Upgrade cost curves
    let cadenceCostBase: Double
    let cadenceCostGrowth: Double
    let neutralizationCostBase: Double
    let neutralizationCostGrowth: Double
    let budgetPerKillCostBase: Double
    let budgetPerKillCostGrowth: Double

    // Absorption / leak
    let absorptionCapacityMax: Double
    let baseLeakCost: Double
    let majorIncidentLeakMultiplier: Double

    // Passive income
    let basePassiveIncomePerSecond: Double
    let passiveIncomePerLevel: Double

    // Offline
    let maxOfflineSeconds: TimeInterval
    let offlineEfficiency: Double

    // Prestige
    let basePrestigePoints: Double
    let prestigeWaveDivisor: Double
    let prestigeExponent: Double
    let prestigeMultiplierPerPoint: Double

    // Housekeeping
    let flashDuration: TimeInterval
    let fireEventFlashDuration: TimeInterval
    let autosaveInterval: TimeInterval

    static func loadBundled() -> GameBalance {
        guard
            let url = Bundle.main.url(forResource: "Balance", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let config = try? JSONDecoder().decode(GameBalance.self, from: data)
        else {
            return fallback
        }
        return config
    }

    // Mirrors Balance.json exactly. If the bundled resource ever fails to
    // load, the game keeps running on these values instead of crashing.
    static let fallback = GameBalance(
        baseAlertCount: 5.0,
        alertCountGrowthPerWave: 0.35,
        majorIncidentVolumeMultiplier: 3.0,
        baseSpawnInterval: 1.4,
        spawnIntervalDecay: 0.985,
        minSpawnInterval: 0.18,
        majorIncidentSpawnIntervalFactor: 0.6,
        baseTravelDuration: 6.0,
        travelDurationDecay: 0.995,
        minTravelDuration: 2.2,
        baseFireInterval: 0.9,
        fireIntervalDecayPerLevel: 0.95,
        minFireInterval: 0.12,
        baseNeutralizationChance: 0.14,
        neutralizationChancePerLevel: 0.015,
        maxNeutralizationChance: 0.75,
        baseBudgetPerKill: 8.0,
        budgetPerKillGrowthPerLevel: 1.08,
        cadenceCostBase: 10.0,
        cadenceCostGrowth: 1.15,
        neutralizationCostBase: 15.0,
        neutralizationCostGrowth: 1.17,
        budgetPerKillCostBase: 20.0,
        budgetPerKillCostGrowth: 1.13,
        absorptionCapacityMax: 140.0,
        baseLeakCost: 4.0,
        majorIncidentLeakMultiplier: 1.5,
        basePassiveIncomePerSecond: 1.0,
        passiveIncomePerLevel: 0.04,
        maxOfflineSeconds: 8 * 3600,
        offlineEfficiency: 0.5,
        basePrestigePoints: 10.0,
        prestigeWaveDivisor: 10.0,
        prestigeExponent: 1.2,
        prestigeMultiplierPerPoint: 0.02,
        flashDuration: 0.4,
        fireEventFlashDuration: 0.35,
        autosaveInterval: 30
    )
}
