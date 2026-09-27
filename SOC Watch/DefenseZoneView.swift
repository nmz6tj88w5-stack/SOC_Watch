import SwiftUI

/// The one view that carries the actual game mechanic. Driven entirely by
/// `Canvas` inside `TimelineView(.animation)`. Every alert's on-screen
/// position is computed fresh, every frame, from the immutable
/// `spawnDate`/`travelDuration` GameEngine exposes — never from a stored
/// progress value duplicated in this view.
struct DefenseZoneView: View {
    let engine: GameEngine

    /// Mirrors GameEngine's internal flash window so a neutralized/leaked
    /// alert fades out on screen for roughly as long as the engine still
    /// keeps it around before purging it.
    private let flashDuration: TimeInterval = 0.4

    /// Mirrors GameEngine.Balance.fireEventFlashDuration — how long a
    /// sensor pulse / engagement beam stays visible after a layer fires.
    private let fireFlashDuration: TimeInterval = 0.35

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxRadius = min(geo.size.width, geo.size.height) * 0.46

            ZStack {
                TimelineView(.animation) { context in
                    Canvas { ctx, _ in
                        drawRings(ctx: ctx, center: center, maxRadius: maxRadius, now: context.date)
                        drawFireEvents(ctx: ctx, center: center, maxRadius: maxRadius, now: context.date)
                        drawCore(ctx: ctx, center: center, maxRadius: maxRadius, now: context.date)
                        for alert in engine.incomingAlerts {
                            drawAlert(alert, ctx: ctx, center: center, maxRadius: maxRadius, now: context.date)
                        }
                    }
                }

                Image(systemName: "lock.shield")
                    .font(.system(size: maxRadius * 0.34))
                    .foregroundStyle(Color(hex: engine.theme.ui.textPrimaryHex))
                    .position(center)
                    .allowsHitTesting(false)

                Text(engine.theme.ui.perimeterLabel)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color(hex: engine.theme.ui.textSecondaryHex))
                    .position(x: center.x, y: geo.size.height - 14)
            }
        }
    }

    // MARK: Rings + sensors

    private func drawRings(ctx: GraphicsContext, center: CGPoint, maxRadius: CGFloat, now: Date) {
        let layers = engine.theme.layers
        let count = max(layers.count, 1)
        for (index, layer) in layers.enumerated() {
            // Outer→inner: index 0 is the outermost ring/band.
            let radius = maxRadius * CGFloat(count - index) / CGFloat(count)
            let ringPath = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            ctx.stroke(ringPath, with: .color(Color(hex: engine.theme.ui.borderHex)), lineWidth: 1)

            // Sensor dot at the top of each ring, colored by the layer
            // that defends that band. Pulses brighter/larger for a beat
            // whenever that layer has just fired — this is the only
            // visible sign that a Cadence upgrade sped anything up, so it
            // has to actually fire on every shot, hit or miss.
            let layerID = LayerID.allCases[index]
            let pulse = firePulse(for: layerID, now: now)
            let sensorPoint = CGPoint(x: center.x, y: center.y - radius)
            let sensorRadius: CGFloat = 4 + pulse.strength * 4
            let sensorPath = Path(ellipseIn: CGRect(x: sensorPoint.x - sensorRadius, y: sensorPoint.y - sensorRadius, width: sensorRadius * 2, height: sensorRadius * 2))
            let sensorColor = Color(hex: layer.colorHex)
            ctx.fill(sensorPath, with: .color(sensorColor.opacity(0.75 + pulse.strength * 0.25)))
            if pulse.strength > 0 {
                let ringRadius = sensorRadius + pulse.strength * 6
                let haloPath = Path(ellipseIn: CGRect(x: sensorPoint.x - ringRadius, y: sensorPoint.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2))
                let haloColor = pulse.hit ? sensorColor : Color(hex: engine.theme.ui.textSecondaryHex)
                ctx.stroke(haloPath, with: .color(haloColor.opacity(pulse.strength * 0.8)), lineWidth: 1.5)
            }
        }
    }

    /// Most recent fire-event pulse strength (1 → just fired, 0 → faded
    /// out) for a given layer, derived fresh from `engine.recentFireEvents`
    /// every frame — no separate pulse state stored in the view.
    private func firePulse(for layerID: LayerID, now: Date) -> (strength: Double, hit: Bool) {
        guard let event = engine.recentFireEvents.last(where: { $0.layerID == layerID }) else {
            return (0, false)
        }
        let elapsed = now.timeIntervalSince(event.firedAt)
        guard elapsed >= 0, elapsed <= fireFlashDuration else { return (0, false) }
        return (1 - elapsed / fireFlashDuration, event.hit)
    }

    private func drawFireEvents(ctx: GraphicsContext, center: CGPoint, maxRadius: CGFloat, now: Date) {
        let layers = engine.theme.layers
        let count = max(layers.count, 1)
        for event in engine.recentFireEvents {
            let elapsed = now.timeIntervalSince(event.firedAt)
            guard elapsed >= 0, elapsed <= fireFlashDuration else { continue }
            let fade = 1 - elapsed / fireFlashDuration
            guard let index = LayerID.allCases.firstIndex(of: event.layerID) else { continue }

            let outerRadius = maxRadius * CGFloat(count - index) / CGFloat(count)
            let innerRadius = maxRadius * CGFloat(count - index - 1) / CGFloat(count)
            let angle = (event.targetAngleDegrees - 90) * Double.pi / 180
            let dx = CGFloat(cos(angle))
            let dy = CGFloat(sin(angle))
            let outerPoint = CGPoint(x: center.x + dx * outerRadius, y: center.y + dy * outerRadius)
            let innerPoint = CGPoint(x: center.x + dx * innerRadius, y: center.y + dy * innerRadius)

            var beam = Path()
            beam.move(to: outerPoint)
            beam.addLine(to: innerPoint)

            let layerColor = Color(hex: engine.theme.layer(event.layerID).colorHex)
            let beamColor = event.hit ? layerColor : Color(hex: engine.theme.ui.textSecondaryHex)
            let width: CGFloat = event.hit ? 2.5 : 1.2
            ctx.stroke(beam, with: .color(beamColor.opacity(fade * (event.hit ? 0.9 : 0.5))), lineWidth: width)
        }
    }

    private func drawCore(ctx: GraphicsContext, center: CGPoint, maxRadius: CGFloat, now: Date) {
        let coreRadius = maxRadius * 0.22
        let breathe = (sin(now.timeIntervalSinceReferenceDate * 2.4) + 1) / 2
        let danger = 1 - engine.absorptionFraction
        let accent = Color(hex: engine.theme.ui.alertHex).opacity(danger * 0.5)
        let calm = Color(hex: engine.theme.layers.first?.colorHex ?? "#4FD1C5")
        let ringColor = calm.opacity(1 - danger * 0.6)

        let glowRadius = coreRadius * (1.15 + breathe * 0.15 * (1 + danger))
        let glowPath = Path(ellipseIn: CGRect(x: center.x - glowRadius, y: center.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2))
        ctx.fill(glowPath, with: .radialGradient(
            Gradient(colors: [accent, .clear]),
            center: center, startRadius: 0, endRadius: glowRadius
        ))

        let corePath = Path(ellipseIn: CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2))
        ctx.fill(corePath, with: .color(Color(hex: engine.theme.ui.cardBackgroundHex)))
        ctx.stroke(corePath, with: .color(ringColor), lineWidth: 2)
    }

    // MARK: Alerts

    private func drawAlert(_ alert: IncomingAlert, ctx: GraphicsContext, center: CGPoint, maxRadius: CGFloat, now: Date) {
        let angle = (alert.ringAngleDegrees - 90) * Double.pi / 180
        let dx = CGFloat(cos(angle))
        let dy = CGFloat(sin(angle))

        if alert.isResolved, let resolvedAt = alert.resolvedAt {
            let elapsed = now.timeIntervalSince(resolvedAt)
            guard elapsed <= flashDuration else { return }
            let fade = 1 - elapsed / flashDuration
            if let layerID = alert.neutralizedByLayer {
                let layerTheme = engine.theme.layer(layerID)
                let radius = maxRadius * CGFloat(1 - alert.progress(at: resolvedAt))
                let point = CGPoint(x: center.x + dx * radius, y: center.y + dy * radius)
                let size = 10 + (1 - fade) * 14
                let burst = Path(ellipseIn: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size))
                ctx.stroke(burst, with: .color(Color(hex: layerTheme.colorHex).opacity(fade)), lineWidth: 2)
            } else {
                // A leak (alert reaching the core unneutralized) is the one
                // event that actually costs absorption capacity — it needs
                // to read as a hit, not a blip, so it gets a filled flash
                // across the whole zone plus a bold shockwave ring, not
                // just a thin outline like the per-layer neutralize burst.
                let alertColor = Color(hex: engine.theme.ui.alertHex)
                let flashRadius = maxRadius * 0.85 * CGFloat(fade)
                let flashPath = Path(ellipseIn: CGRect(x: center.x - flashRadius, y: center.y - flashRadius, width: flashRadius * 2, height: flashRadius * 2))
                ctx.fill(flashPath, with: .radialGradient(
                    Gradient(colors: [alertColor.opacity(fade * 0.5), .clear]),
                    center: center, startRadius: 0, endRadius: flashRadius
                ))

                let size = 24 + (1 - fade) * 60
                let burst = Path(ellipseIn: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size))
                ctx.stroke(burst, with: .color(alertColor.opacity(fade)), lineWidth: 4)
            }
            return
        }

        let progress = alert.progress(at: now)
        let radius = maxRadius * CGFloat(1 - progress)
        let point = CGPoint(x: center.x + dx * radius, y: center.y + dy * radius)
        let pulse = (sin(now.timeIntervalSinceReferenceDate * 5 + alert.ringAngleDegrees) + 1) / 2
        let dotRadius: CGFloat = 5 + pulse * 1.5
        // Diamond, not a circle — sensors (defense) are round dots on the
        // rings, so incoming alerts (attacks) need a different silhouette
        // to read as distinct at a glance, not just a different color.
        var alertPath = Path()
        alertPath.move(to: CGPoint(x: point.x, y: point.y - dotRadius))
        alertPath.addLine(to: CGPoint(x: point.x + dotRadius, y: point.y))
        alertPath.addLine(to: CGPoint(x: point.x, y: point.y + dotRadius))
        alertPath.addLine(to: CGPoint(x: point.x - dotRadius, y: point.y))
        alertPath.closeSubpath()
        ctx.fill(alertPath, with: .color(Color(hex: engine.theme.ui.alertHex).opacity(0.55 + pulse * 0.45)))
    }
}
