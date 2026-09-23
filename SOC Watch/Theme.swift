import SwiftUI

struct AxisTheme: Codable {
    let label: String
    let shortLabel: String
    let unitSuffix: String
}

struct LayerAxesTheme: Codable {
    let cadence: AxisTheme
    let neutralization: AxisTheme
    let budgetPerKill: AxisTheme
}

struct LayerTheme: Codable {
    let id: String
    let name: String
    let colorHex: String
    let icon: String
    let axes: LayerAxesTheme
}

struct MajorIncidentTheme: Codable {
    let label: String
}

struct OnboardingStepTheme: Codable {
    let icon: String
    let title: String
    let body: String
}

struct OnboardingTheme: Codable {
    let title: String
    let intro: String
    let steps: [OnboardingStepTheme]
    let dismissLabel: String
}

struct NotificationsTheme: Codable {
    let postMortemTitle: String
    let postMortemBody: String
    let criticalTitle: String
    let criticalBody: String
    let idleTitle: String
    let idleBody: String
}

struct BreachTheme: Codable {
    let title: String
    let messageFormat: String
    let postMortemLabel: String
    let postMortemBonusFormat: String
    let postMortemBestWaveFormat: String
}

struct UITheme: Codable {
    let backgroundHex: String
    let cardBackgroundHex: String
    let borderHex: String
    let borderSecondaryHex: String
    let textPrimaryHex: String
    let textSecondaryHex: String
    let alertHex: String
    let waveLabel: String
    let absorptionLabel: String
    let perimeterLabel: String
    let welcomeBackFormat: String
    let maxLabel: String
    let levelFormat: String
}

struct ThemeConfig: Codable {
    let gameTitle: String
    let currencyName: String
    let currencySymbol: String
    let layers: [LayerTheme]
    let majorIncident: MajorIncidentTheme
    let breach: BreachTheme
    let onboarding: OnboardingTheme
    let notifications: NotificationsTheme
    let ui: UITheme

    func layer(_ id: LayerID) -> LayerTheme {
        layers.first { $0.id == id.rawValue } ?? Self.fallback.layers[0]
    }

    static func loadBundled() -> ThemeConfig {
        guard
            let url = Bundle.main.url(forResource: "Theme", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let config = try? JSONDecoder().decode(ThemeConfig.self, from: data)
        else {
            return fallback
        }
        return config
    }

    // Minimal hardcoded fallback so a resource-packaging mistake degrades
    // gracefully instead of crashing the app at launch.
    static let fallback = ThemeConfig(
        gameTitle: "SOC WATCH",
        currencyName: "Budget",
        currencySymbol: "$",
        layers: [
            LayerTheme(id: "edr", name: "EDR", colorHex: "#4FD1C5", icon: "bolt.shield.fill",
                       axes: LayerAxesTheme(
                        cadence: AxisTheme(label: "Detection Cadence", shortLabel: "Cadence", unitSuffix: "/s"),
                        neutralization: AxisTheme(label: "Immediate Neutralization Chance", shortLabel: "Neutralize", unitSuffix: "%"),
                        budgetPerKill: AxisTheme(label: "Budget per Neutralized Alert", shortLabel: "Budget/Kill", unitSuffix: ""))),
            LayerTheme(id: "siem", name: "SIEM", colorHex: "#F2A65A", icon: "gearshape.fill",
                       axes: LayerAxesTheme(
                        cadence: AxisTheme(label: "Correlation Cadence", shortLabel: "Cadence", unitSuffix: "/s"),
                        neutralization: AxisTheme(label: "Immediate Neutralization Chance", shortLabel: "Neutralize", unitSuffix: "%"),
                        budgetPerKill: AxisTheme(label: "Budget per Neutralized Alert", shortLabel: "Budget/Kill", unitSuffix: ""))),
            LayerTheme(id: "threatIntel", name: "Threat Intel", colorHex: "#8A97A3", icon: "checkmark.shield.fill",
                       axes: LayerAxesTheme(
                        cadence: AxisTheme(label: "Analysis Cadence", shortLabel: "Cadence", unitSuffix: "/s"),
                        neutralization: AxisTheme(label: "Immediate Neutralization Chance", shortLabel: "Neutralize", unitSuffix: "%"),
                        budgetPerKill: AxisTheme(label: "Budget per Neutralized Alert", shortLabel: "Budget/Kill", unitSuffix: "")))
        ],
        majorIncident: MajorIncidentTheme(label: "MAJOR INCIDENT"),
        breach: BreachTheme(title: "BREACH DETECTED",
                             messageFormat: "Absorption capacity exhausted at wave %d.",
                             postMortemLabel: "POST-MORTEM",
                             postMortemBonusFormat: "+%.0f%% permanent",
                             postMortemBestWaveFormat: "Best wave: %d"),
        onboarding: OnboardingTheme(
            title: "Welcome to the SOC",
            intro: "Alerts keep coming. Your three layers try to stop them before they reach the core.",
            steps: [
                OnboardingStepTheme(icon: "shield.lefthalf.filled", title: "Three Layers, Three Rings",
                                    body: "EDR, SIEM, and Threat Intel each guard one ring. An alert has to get past all three to breach your core."),
                OnboardingStepTheme(icon: "slider.horizontal.3", title: "Three Upgrades Each",
                                    body: "Cadence (fire rate), Neutralize (one-shot chance), and Budget/Kill (payout) — spread upgrades across all three, not just one."),
                OnboardingStepTheme(icon: "gauge.with.needle.fill", title: "Watch Absorption Capacity",
                                    body: "It only drops when an alert leaks through. Hit zero and you breach — but you keep a permanent bonus for next run.")
            ],
            dismissLabel: "Got it — let's go"
        ),
        notifications: NotificationsTheme(
            postMortemTitle: "Your permanent bonus is ready",
            postMortemBody: "SOC Watch banked a permanent bonus from your last run — come back and put it to work.",
            criticalTitle: "Absorption capacity critical",
            criticalBody: "Your SOC was close to a breach when you left. Jump back in and shore up your defenses.",
            idleTitle: "Your SOC has been quiet",
            idleBody: "Budget has been piling up while you were away. Come see how far you can push this run."
        ),
        ui: UITheme(backgroundHex: "#0B0F14", cardBackgroundHex: "#131A22", borderHex: "#1C2530",
                    borderSecondaryHex: "#2C3946", textPrimaryHex: "#E7ECEF", textSecondaryHex: "#8A97A3",
                    alertHex: "#E5484D", waveLabel: "INCIDENT WAVE", absorptionLabel: "ABSORPTION CAPACITY",
                    perimeterLabel: "Perimeter · EDR · SIEM · Threat Intel",
                    welcomeBackFormat: "Welcome back · +%@ while you were away", maxLabel: "MAX",
                    levelFormat: "%@ — Lv. %d")
    )
}

extension Color {
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.removeAll { $0 == "#" }
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
