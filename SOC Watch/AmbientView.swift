import SwiftUI

/// Purely decorative. Continuously animates from wall-clock time alone —
/// never reads or references GameEngine, so it can never drift out of sync
/// with game state because it never depends on any.
struct AmbientView: View {
    let theme: ThemeConfig

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let background = Color(hex: theme.ui.backgroundHex)
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background))

                let center = CGPoint(x: size.width / 2, y: size.height * 0.42)
                for (index, layer) in theme.layers.enumerated() {
                    let phase = t * 0.6 + Double(index) * 2.1
                    let breathe = (sin(phase) + 1) / 2 // 0...1
                    let radius = size.width * 0.32 + breathe * 18
                    let opacity = 0.05 + breathe * 0.06
                    let color = Color(hex: layer.colorHex)
                    let rect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    ctx.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
                            center: center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
