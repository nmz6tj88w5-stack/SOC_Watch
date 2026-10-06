import Foundation
import Observation

/// Owns every game rule: waves, spawn/leak math, layer fire resolution,
/// budget accrual, upgrade cost curves, and prestige. No copy or color is
/// ever hardcoded here — all player-facing content lives in `theme`.
@MainActor
@Observable
final class GameEngine {

    // MARK: Public read state

    let theme: ThemeConfig
    private(set) var state: GameState
    private(set) var incomingAlerts: [IncomingAlert] = []
    /// Purely for visual feedback — see FireEvent's doc comment.
    private(set) var recentFireEvents: [FireEvent] = []
    private(set) var lastBreachSummary: BreachSummary?
    private(set) var lastOfflineGain: Double?
    /// Monotonic-within-a-run counters, purely so views can drive
    /// haptic/sound feedback off a value that changes exactly once per
    /// real event (SwiftUI's `.sensoryFeedback(trigger:)` needs a
    /// comparable value, not an event stream).
    private(set) var totalKillCount: Int = 0

    var totalUpgradeLevelCount: Int {
        state.layers.values.reduce(0) { $0 + $1.cadenceLevel + $1.neutralizationLevel + $1.budgetPerKillLevel }
    }

    /// Every X waves a Major Incident spawns. Parameterizable, defaults to 10.
    var majorIncidentEveryN: Int = 10

    var waveProgress: Double {
        guard waveAlertsTotal > 0 else { return 0 }
        return min(1, Double(waveAlertsResolved) / Double(waveAlertsTotal))
    }

    var absorptionFraction: Double {
        guard state.absorptionCapacityMax > 0 else { return 0 }
        return max(0, state.absorptionCapacity / state.absorptionCapacityMax)
    }

    var isMajorIncidentWave: Bool { isMajor(state.currentWave) }

    // MARK: Runtime-only wave/combat state (never persisted; a mid-wave
    // relaunch restarts the current wave's spawn batch fresh rather than
    // reconstructing exact in-flight alerts).

    private var waveAlertsTotal = 0
    private var waveAlertsSpawned = 0
    private var waveAlertsResolved = 0
    private var nextSpawnTime = Date()
    private var fireNextTime: [LayerID: Date] = [:]
    private var lastTickTime: Date?
    private var lastPersistTime = Date()

    private let persistence: PersistenceService
    private let balance: GameBalance

    init(theme: ThemeConfig, balance: GameBalance, persistence: PersistenceService) {
        self.theme = theme
        self.balance = balance
        self.persistence = persistence
        self.state = persistence.load() ?? GameState.initial(absorptionCapacityMax: balance.absorptionCapacityMax)
        configureWave(state.currentWave, referenceDate: Date())
    }

    // MARK: Simulation tick

    func tick(now: Date) {
        spawnAlertsIfNeeded(now: now)
        resolveLayerFire(now: now)
        applyPassiveIncome(now: now)
        resolveLeaks(now: now)
        purgeStaleAlerts(now: now)
        advanceWaveIfComplete(now: now)
        if state.absorptionCapacity <= 0 {
            triggerBreachAndPostMortem(now: now)
        }
        autosaveIfNeeded(now: now)
    }

    private func spawnAlertsIfNeeded(now: Date) {
        while waveAlertsSpawned < waveAlertsTotal && now >= nextSpawnTime {
            let alert = IncomingAlert(
                ringAngleDegrees: Double.random(in: 0..<360),
                spawnDate: nextSpawnTime,
                travelDuration: travelDuration(for: state.currentWave)
            )
            incomingAlerts.append(alert)
            waveAlertsSpawned += 1
            nextSpawnTime = nextSpawnTime.addingTimeInterval(spawnInterval(for: state.currentWave))
        }
    }

    private func resolveLayerFire(now: Date) {
        let layers = LayerID.allCases
        for (index, layerID) in layers.enumerated() {
            let nextFire = fireNextTime[layerID] ?? now
            guard now >= nextFire else { continue }
            fireNextTime[layerID] = now.addingTimeInterval(fireInterval(for: layerID))

            let lower = Double(index) / Double(layers.count)
            let upper = Double(index + 1) / Double(layers.count)
            guard let targetIndex = indexOfMostProgressedAlert(now: now, lower: lower, upper: upper, excluding: layerID) else { continue }

            let hit = Double.random(in: 0..<1) < neutralizationChance(for: layerID)
            recentFireEvents.append(FireEvent(
                layerID: layerID,
                firedAt: now,
                hit: hit,
                targetAngleDegrees: incomingAlerts[targetIndex].ringAngleDegrees
            ))
            if hit {
                neutralize(alertIndex: targetIndex, by: layerID, now: now)
            } else {
                incomingAlerts[targetIndex].attemptedByLayers.insert(layerID)
            }
        }
    }

    private func indexOfMostProgressedAlert(now: Date, lower: Double, upper: Double, excluding layerID: LayerID) -> Int? {
        var bestIndex: Int?
        var bestProgress = -1.0
        for (i, alert) in incomingAlerts.enumerated() {
            guard !alert.isResolved, !alert.attemptedByLayers.contains(layerID) else { continue }
            let p = alert.progress(at: now)
            guard p >= lower, p < upper else { continue }
            if p > bestProgress {
                bestProgress = p
                bestIndex = i
            }
        }
        return bestIndex
    }

    private func neutralize(alertIndex: Int, by layerID: LayerID, now: Date) {
        incomingAlerts[alertIndex].isResolved = true
        incomingAlerts[alertIndex].resolvedAt = now
        incomingAlerts[alertIndex].neutralizedByLayer = layerID
        waveAlertsResolved += 1
        totalKillCount += 1
        state.budget += budgetPerKill(for: layerID) * state.prestigeMultiplier
    }

    private func applyPassiveIncome(now: Date) {
        guard let last = lastTickTime else {
            lastTickTime = now
            return
        }
        lastTickTime = now
        let dt = now.timeIntervalSince(last)
        guard dt > 0 else { return }
        state.budget += passiveIncomePerSecond() * dt
    }

    private func resolveLeaks(now: Date) {
        for i in incomingAlerts.indices where !incomingAlerts[i].isResolved {
            guard incomingAlerts[i].progress(at: now) >= 1.0 else { continue }
            incomingAlerts[i].isResolved = true
            incomingAlerts[i].resolvedAt = now
            waveAlertsResolved += 1
            state.absorptionCapacity -= leakCost(for: state.currentWave)
        }
    }

    private func purgeStaleAlerts(now: Date) {
        incomingAlerts.removeAll { alert in
            guard alert.isResolved, let resolvedAt = alert.resolvedAt else { return false }
            return now.timeIntervalSince(resolvedAt) > balance.flashDuration
        }
        recentFireEvents.removeAll { now.timeIntervalSince($0.firedAt) > balance.fireEventFlashDuration }
    }

    private func advanceWaveIfComplete(now: Date) {
        guard waveAlertsTotal > 0,
              waveAlertsSpawned >= waveAlertsTotal,
              waveAlertsResolved >= waveAlertsTotal else { return }
        state.currentWave += 1
        configureWave(state.currentWave, referenceDate: now)
    }

    private func configureWave(_ wave: Int, referenceDate: Date) {
        waveAlertsTotal = alertCount(for: wave)
        waveAlertsSpawned = 0
        waveAlertsResolved = 0
        nextSpawnTime = referenceDate
    }

    // MARK: Prestige

    private func triggerBreachAndPostMortem(now: Date) {
        let waveReached = state.currentWave
        state.bestWaveReached = max(state.bestWaveReached, waveReached)

        let rawPoints = balance.basePrestigePoints * pow(Double(waveReached) / balance.prestigeWaveDivisor, balance.prestigeExponent)
        let pointsEarned = max(0, rawPoints.rounded(.down))
        state.totalPrestigePoints += pointsEarned
        state.prestigeMultiplier = 1.0 + state.totalPrestigePoints * balance.prestigeMultiplierPerPoint
        state.totalPostMortems += 1

        lastBreachSummary = BreachSummary(
            waveReached: waveReached,
            pointsEarned: pointsEarned,
            newMultiplier: state.prestigeMultiplier,
            occurredAt: now
        )

        resetRun(now: now)
        persist()
    }

    private func resetRun(now: Date) {
        state.budget = 0
        state.currentWave = 1
        state.absorptionCapacity = state.absorptionCapacityMax
        for id in LayerID.allCases { state.layers[id] = LayerState() }
        incomingAlerts.removeAll()
        recentFireEvents.removeAll()
        fireNextTime.removeAll()
        configureWave(state.currentWave, referenceDate: now)
    }

    // MARK: Upgrades

    func costFor(layer: LayerID, axis: UpgradeAxis) -> Double {
        let level = state.layers[layer]?.level(for: axis) ?? 0
        switch axis {
        case .cadence:
            return (balance.cadenceCostBase * pow(balance.cadenceCostGrowth, Double(level))).rounded(.up)
        case .neutralization:
            return (balance.neutralizationCostBase * pow(balance.neutralizationCostGrowth, Double(level))).rounded(.up)
        case .budgetPerKill:
            return (balance.budgetPerKillCostBase * pow(balance.budgetPerKillCostGrowth, Double(level))).rounded(.up)
        }
    }

    func isMaxed(layer: LayerID, axis: UpgradeAxis) -> Bool {
        guard axis == .neutralization else { return false }
        return neutralizationChance(for: layer) >= balance.maxNeutralizationChance
    }

    func canAfford(layer: LayerID, axis: UpgradeAxis) -> Bool {
        !isMaxed(layer: layer, axis: axis) && state.budget >= costFor(layer: layer, axis: axis)
    }

    func purchaseUpgrade(layer: LayerID, axis: UpgradeAxis) {
        guard canAfford(layer: layer, axis: axis) else { return }
        let cost = costFor(layer: layer, axis: axis)
        state.budget -= cost
        state.layers[layer]?.incrementLevel(for: axis)
    }

    // MARK: Offline progress

    func applyOfflineProgress(now: Date) {
        let elapsed = min(now.timeIntervalSince(state.lastActiveTimestamp), balance.maxOfflineSeconds)
        state.lastActiveTimestamp = now
        lastTickTime = now
        guard elapsed > 1 else {
            lastOfflineGain = nil
            return
        }
        let gained = passiveIncomePerSecond() * elapsed * balance.offlineEfficiency
        state.budget += gained
        lastOfflineGain = gained
        persist()
    }

    /// Grants a second copy of the just-applied offline gain (e.g. after
    /// watching a rewarded ad) and clears `lastOfflineGain`, which also
    /// hides the "welcome back" banner/button in the HUD — reusing that
    /// field as the single source of truth instead of adding a new flag.
    func claimOfflineGainBoost() {
        guard let gained = lastOfflineGain else { return }
        state.budget += gained
        lastOfflineGain = nil
        persist()
    }

    // MARK: Persistence

    func persist() {
        state.lastActiveTimestamp = Date()
        persistence.save(state)
    }

    /// Install-level flag (not game progress) — see PersistenceService.
    var hasCompletedOnboarding: Bool { persistence.hasSeenOnboarding() }

    func completeOnboarding() {
        persistence.setHasSeenOnboarding(true)
    }

    private func autosaveIfNeeded(now: Date) {
        guard now.timeIntervalSince(lastPersistTime) >= balance.autosaveInterval else { return }
        lastPersistTime = now
        persist()
    }

    // MARK: Formulas

    private func isMajor(_ wave: Int) -> Bool {
        majorIncidentEveryN > 0 && wave % majorIncidentEveryN == 0
    }

    /// Exponential (compounding) growth per wave, not linear — see
    /// `GameBalance.alertCountGrowthFactor`'s doc comment for why.
    private func alertCount(for wave: Int) -> Int {
        let base = balance.baseAlertCount * pow(balance.alertCountGrowthFactor, Double(wave))
        let multiplier = isMajor(wave) ? balance.majorIncidentVolumeMultiplier : 1.0
        return max(1, Int((base * multiplier).rounded()))
    }

    private func spawnInterval(for wave: Int) -> TimeInterval {
        let base = max(balance.minSpawnInterval, balance.baseSpawnInterval * pow(balance.spawnIntervalDecay, Double(wave)))
        return base * (isMajor(wave) ? balance.majorIncidentSpawnIntervalFactor : 1.0)
    }

    private func travelDuration(for wave: Int) -> TimeInterval {
        max(balance.minTravelDuration, balance.baseTravelDuration * pow(balance.travelDurationDecay, Double(wave)))
    }

    private func leakCost(for wave: Int) -> Double {
        balance.baseLeakCost * (isMajor(wave) ? balance.majorIncidentLeakMultiplier : 1.0)
    }

    private func fireInterval(for layerID: LayerID) -> TimeInterval {
        let level = state.layers[layerID]?.cadenceLevel ?? 0
        return max(balance.minFireInterval, balance.baseFireInterval * pow(balance.fireIntervalDecayPerLevel, Double(level)))
    }

    private func neutralizationChance(for layerID: LayerID) -> Double {
        let level = state.layers[layerID]?.neutralizationLevel ?? 0
        return min(balance.maxNeutralizationChance, balance.baseNeutralizationChance + Double(level) * balance.neutralizationChancePerLevel)
    }

    private func budgetPerKill(for layerID: LayerID) -> Double {
        let level = state.layers[layerID]?.budgetPerKillLevel ?? 0
        return balance.baseBudgetPerKill * pow(balance.budgetPerKillGrowthPerLevel, Double(level))
    }

    private func passiveIncomePerSecond() -> Double {
        return balance.basePassiveIncomePerSecond * (1 + Double(totalUpgradeLevelCount) * balance.passiveIncomePerLevel) * state.prestigeMultiplier
    }
}
