import SwiftUI

/// State-driven layer: everything here reacts to GameEngine state changes
/// with classic `withAnimation(.easeInOut(duration: 0.3))` transitions.
/// Split into two composable pieces (`TopHUDView`, `UpgradePanelView`) so
/// ContentView can place them above/below the defense zone, matching the
/// mockup's layout, while both still live in this single file.

struct TopHUDView: View {
    let engine: GameEngine

    private var theme: ThemeConfig { engine.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(Color(hex: theme.layers.first?.colorHex ?? "#4FD1C5"))
                    Text(theme.gameTitle)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Color(hex: theme.ui.textPrimaryHex))
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "banknote.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#F2A65A"))
                    Text(formattedNumber(engine.state.budget))
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Color(hex: "#F2A65A"))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: engine.state.budget)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: theme.ui.cardBackgroundHex), in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(theme.ui.waveLabel) \(engine.state.currentWave)")
                        .font(.system(.caption2, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(Color(hex: theme.ui.textSecondaryHex))
                    if engine.isMajorIncidentWave {
                        Text(theme.majorIncident.label)
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(Color(hex: theme.ui.alertHex))
                    }
                    Spacer()
                    Text("\(Int((engine.waveProgress * 100).rounded()))%")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color(hex: theme.ui.textSecondaryHex))
                }
                progressBar(value: engine.waveProgress, color: Color(hex: theme.layers.first?.colorHex ?? "#4FD1C5"))

                Text(theme.ui.absorptionLabel)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color(hex: theme.ui.textSecondaryHex))
                progressBar(value: engine.absorptionFraction, color: absorptionColor)
            }

            if let gain = engine.lastOfflineGain {
                Text(String(format: theme.ui.welcomeBackFormat, formattedNumber(gain)))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color(hex: "#4FD1C5"))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(Color(hex: theme.ui.backgroundHex))
        .overlay(Rectangle().fill(Color(hex: theme.ui.borderHex)).frame(height: 1), alignment: .bottom)
        .animation(.easeInOut(duration: 0.3), value: engine.state.currentWave)
    }

    private func progressBar(value: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: theme.ui.borderHex))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * value))
                    .animation(.easeInOut(duration: 0.3), value: value)
            }
        }
        .frame(height: 6)
    }

    private var absorptionColor: Color {
        engine.absorptionFraction < 0.3 ? Color(hex: theme.ui.alertHex) : Color(hex: "#4FD1C5")
    }

    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}

struct UpgradePanelView: View {
    let engine: GameEngine

    private var theme: ThemeConfig { engine.theme }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(LayerID.allCases, id: \.self) { layerID in
                LayerCard(engine: engine, layerID: layerID)
            }
            PostMortemStatusTile(engine: engine)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(Color(hex: "#0E141B"))
        .overlay(Rectangle().fill(Color(hex: theme.ui.borderHex)).frame(height: 1), alignment: .top)
    }
}

private struct LayerCard: View {
    let engine: GameEngine
    let layerID: LayerID

    private var theme: ThemeConfig { engine.theme }
    private var layerTheme: LayerTheme { theme.layer(layerID) }
    private var layerColor: Color { Color(hex: layerTheme.colorHex) }
    private var layerState: LayerState { engine.state.layers[layerID] ?? LayerState() }
    private var totalLevel: Int {
        layerState.cadenceLevel + layerState.neutralizationLevel + layerState.budgetPerKillLevel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: layerTheme.icon)
                    .foregroundStyle(layerColor)
                    .frame(width: 22)
                Text(String(format: theme.ui.levelFormat, layerTheme.name, totalLevel))
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Color(hex: theme.ui.textPrimaryHex))
                    .contentTransition(.numericText())
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(UpgradeAxis.allCases, id: \.self) { axis in
                    AxisUpgradeButton(engine: engine, layerID: layerID, axis: axis, accent: layerColor)
                }
            }
        }
        .padding(12)
        .background(Color(hex: theme.ui.cardBackgroundHex), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: theme.ui.borderHex)))
        .animation(.easeInOut(duration: 0.3), value: totalLevel)
    }
}

private struct AxisUpgradeButton: View {
    let engine: GameEngine
    let layerID: LayerID
    let axis: UpgradeAxis
    let accent: Color

    private var theme: ThemeConfig { engine.theme }
    private var axisTheme: AxisTheme {
        let axes = theme.layer(layerID).axes
        switch axis {
        case .cadence: return axes.cadence
        case .neutralization: return axes.neutralization
        case .budgetPerKill: return axes.budgetPerKill
        }
    }
    private var maxed: Bool { engine.isMaxed(layer: layerID, axis: axis) }
    private var affordable: Bool { engine.canAfford(layer: layerID, axis: axis) }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                engine.purchaseUpgrade(layer: layerID, axis: axis)
            }
        } label: {
            VStack(spacing: 2) {
                Text(axisTheme.shortLabel)
                    .font(.system(.caption2, weight: .semibold))
                Text(maxed ? theme.ui.maxLabel : costText)
                    .font(.system(.caption2, design: .monospaced))
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(fillColor)
            )
            .foregroundStyle(labelColor)
        }
        .buttonStyle(.plain)
        .disabled(maxed || !affordable)
        .animation(.easeInOut(duration: 0.3), value: affordable)
    }

    private var fillColor: Color {
        if maxed { return Color(hex: theme.ui.borderSecondaryHex).opacity(0.4) }
        return affordable ? accent : Color(hex: theme.ui.borderSecondaryHex)
    }

    private var labelColor: Color {
        (affordable && !maxed) ? Color(hex: theme.ui.backgroundHex) : Color(hex: theme.ui.textSecondaryHex)
    }

    private var costText: String {
        String(Int(engine.costFor(layer: layerID, axis: axis)))
    }
}

private struct PostMortemStatusTile: View {
    let engine: GameEngine
    @State private var highlight = false

    private var theme: ThemeConfig { engine.theme }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.counterclockwise.circle")
                .foregroundStyle(Color(hex: theme.ui.alertHex))
            VStack(alignment: .leading, spacing: 2) {
                Text(theme.breach.postMortemLabel)
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(Color(hex: theme.ui.alertHex))
                Text(subtitle)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color(hex: theme.ui.textSecondaryHex))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(highlight ? Color(hex: theme.ui.alertHex).opacity(0.08) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(hex: theme.ui.alertHex).opacity(highlight ? 1 : 0.5), lineWidth: highlight ? 2 : 1)
        )
        .onChange(of: engine.lastBreachSummary) { _, newValue in
            guard newValue != nil else { return }
            withAnimation(.easeInOut(duration: 0.3)) { highlight = true }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeInOut(duration: 0.3)) { highlight = false }
            }
        }
    }

    private var subtitle: String {
        let bonusPercent = (engine.state.prestigeMultiplier - 1) * 100
        let bonusText = String(format: theme.breach.postMortemBonusFormat, bonusPercent)
        let waveText = String(format: theme.breach.postMortemBestWaveFormat, engine.state.bestWaveReached)
        return "\(bonusText) · \(waveText)"
    }
}
