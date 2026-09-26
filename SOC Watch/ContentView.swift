import SwiftUI

struct ContentView: View {
    @State private var engine: GameEngine
    @Environment(\.scenePhase) private var scenePhase
    @State private var showOnboarding: Bool
    /// True while the native notification-permission dialog is up. It's
    /// system UI, not a SwiftUI sheet, so nothing else here would
    /// otherwise notice it's blocking the screen.
    @State private var isAwaitingNotificationPermission = false
    /// Tracks the current foreground session's start, purely for the
    /// session_ended analytics duration — reset every time the app returns
    /// to .active from the background.
    @State private var sessionStartDate = Date()

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
        .onChange(of: engine.lastBreachSummary) { _, summary in
            FeedbackService.playBreachSound()
            if let summary {
                AnalyticsService.breach(waveReached: summary.waveReached, pointsEarned: summary.pointsEarned, newMultiplier: summary.newMultiplier)
            }
        }
        .onChange(of: engine.state.currentWave) { _, newWave in
            AnalyticsService.waveReached(newWave)
        }
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
                AnalyticsService.onboardingCompleted()
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
                if let gained = engine.lastOfflineGain {
                    AnalyticsService.offlineGainApplied(gained: gained)
                }
                NotificationService.cancelReengagement()
                sessionStartDate = Date()
                AnalyticsService.sessionStarted()
            case .background:
                engine.persist()
                AnalyticsService.sessionEnded(durationSeconds: Date().timeIntervalSince(sessionStartDate))
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
