import SwiftUI

/// First-run explainer, shown once as a sheet from ContentView. Purely
/// state-driven (reacts to a dismiss action, no ambient animation, no
/// direct Canvas/game-mechanic ownership) — content comes entirely from
/// `theme.onboarding`, matching the reskin-via-JSON architecture.
struct OnboardingView: View {
    let theme: ThemeConfig
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(theme.onboarding.title)
                            .font(.system(.title2, weight: .bold))
                            .foregroundStyle(Color(hex: theme.ui.textPrimaryHex))
                        Text(theme.onboarding.intro)
                            .font(.system(.subheadline))
                            .foregroundStyle(Color(hex: theme.ui.textSecondaryHex))
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(theme.onboarding.steps.enumerated()), id: \.offset) { _, step in
                            OnboardingStepRow(theme: theme, step: step)
                        }
                    }
                }
                .padding(.horizontal, 22)
            }

            Button(action: onDismiss) {
                Text(theme.onboarding.dismissLabel)
                    .font(.system(.body, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(Color(hex: theme.ui.backgroundHex))
                    .background(Color(hex: theme.layers.first?.colorHex ?? "#4FD1C5"), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .background(Color(hex: theme.ui.backgroundHex))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }
}

private struct OnboardingStepRow: View {
    let theme: ThemeConfig
    let step: OnboardingStepTheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: step.icon)
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: theme.layers.first?.colorHex ?? "#4FD1C5"))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Color(hex: theme.ui.textPrimaryHex))
                Text(step.body)
                    .font(.system(.footnote))
                    .foregroundStyle(Color(hex: theme.ui.textSecondaryHex))
            }
        }
    }
}
