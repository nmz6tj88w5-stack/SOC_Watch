import SwiftUI

struct ContentView: View {
    @State private var engine: GameEngine
    @Environment(\.scenePhase) private var scenePhase
    @State private var showOnboarding: Bool
    /// True while the native notification-permission dialog is up. It's
    /// system UI, not a SwiftUI sheet, so nothing else here would
    /// otherwise notice it's blocking the screen.
    @State private var isAwaitingNotificationPermission = false

    init() {
        let engine = GameEngine(
            theme: ThemeConfig.loadBundled(),
            balance: GameBalance.loadBundled(),
            persistence: PersistenceService()
        )
        _engine = State(initialValue: engine)
        // Computed here, not in .onAppear, so the tick loop below never
        // has a frame where it doesn't yet know onboarding is pending.
        _showOnboarding = State(initialValue: !engine.hasCompletedOnboarding)
    }

    var body: some View {
        ZStack {
            AmbientView(theme: engine.theme)
            VStack(spacing: 0) {
                TopHUDView(engine: engine)
                DefenseZoneView(engine: engine)
                UpgradePanelView(engine: engine)
            }
        }
        .background(Color(hex: engine.theme.ui.backgroundHex))
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .light), trigger: engine.totalKillCount)
        .sensoryFeedback(.selection, trigger: engine.totalUpgradeLevelCount)
        .sensoryFeedback(.error, trigger: engine.lastBreachSummary)
        .onChange(of: engine.totalKillCount) { _, _ in FeedbackService.playKillSound() }
        .onChange(of: engine.totalUpgradeLevelCount) { _, _ in FeedbackService.playPurchaseSound() }
        .onChange(of: engine.lastBreachSummary) { _, _ in FeedbackService.playBreachSound() }
        .task {
            while !Task.isCancelled {
                // Don't let waves/combat run behind the onboarding sheet
                // or the native notification-permission dialog — a
                // first-time player shouldn't lose absorption capacity to
                // alerts they had no chance to react to.
                if !showOnboarding && !isAwaitingNotificationPermission {
                    engine.tick(now: Date())
                }
                try? await Task.sleep(for: .milliseconds(66))
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(theme: engine.theme) {
                engine.completeOnboarding()
                showOnboarding = false
                isAwaitingNotificationPermission = true
                Task {
                    await NotificationService.requestAuthorization()
                    isAwaitingNotificationPermission = false
                }
            }
        }
        .onChange(of: scenePhase) { old, new in
            switch new {
            case .active where old != .active:
                engine.applyOfflineProgress(now: Date())
                NotificationService.cancelReengagement()
            case .background:
                engine.persist()
                NotificationService.scheduleReengagement(
                    theme: engine.theme,
                    breachSummary: engine.lastBreachSummary,
                    absorptionFraction: engine.absorptionFraction,
                    now: Date()
                )
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
