import SwiftUI

// Mémoire design system — airy blue gradients, floating white cards,
// generous radii, wide geometric display type. Stories are set in a serif
// so the storyteller's words read like a book.

enum Theme {
    // MARK: Colors
    static let blue = Color(hex: 0x1A86FF)
    static let blueDeep = Color(hex: 0x0A6CF0)
    static let blueSky = Color(hex: 0x6CB8FF)
    static let blueMist = Color(hex: 0xD9ECFF)
    static let blueWash = Color(hex: 0xEEF6FF)

    static let canvas = Color(hex: 0xF3F6FB)
    static let card = Color.white
    static let ink = Color(hex: 0x12151C)
    static let inkSoft = Color(hex: 0x3B4250)
    static let mute = Color(hex: 0x8A93A3)
    static let hairline = Color(hex: 0xE6EAF1)

    static let orange = Color(hex: 0xFF8A3D)
    static let orangeWash = Color(hex: 0xFFEFE3)
    static let green = Color(hex: 0x2FC46B)
    static let greenWash = Color(hex: 0xE3F8EC)
    static let purple = Color(hex: 0x8B6CFF)
    static let purpleWash = Color(hex: 0xF0EBFF)
    static let red = Color(hex: 0xEE2E2E)

    // MARK: Gradients
    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x0E7BFF), Color(hex: 0x3D9DFF), Color(hex: 0x9FD0FF)],
        startPoint: .top, endPoint: .bottom)

    static let cardGradient = LinearGradient(
        colors: [Color(hex: 0x1384FF), Color(hex: 0x4FA8FF)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let callGradient = LinearGradient(
        colors: [Color(hex: 0x0B78FF), Color(hex: 0x4AA6FF), Color(hex: 0xCFE7FF), Color(hex: 0xF3F6FB)],
        startPoint: .top, endPoint: .bottom)

    static let fadeToCanvas = LinearGradient(
        colors: [Color(hex: 0x1A86FF), Color(hex: 0x6CB8FF), Color(hex: 0xF3F6FB).opacity(0.0)],
        startPoint: .top, endPoint: .bottom)

    // MARK: Radii & spacing
    static let radiusXL: CGFloat = 32
    static let radiusL: CGFloat = 24
    static let radiusM: CGFloat = 18
    static let radiusS: CGFloat = 12
    static let gutter: CGFloat = 20
}

// MARK: - Typography

extension Font {
    /// Wide geometric display face, close to the reference mockups.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.expanded)
    }
    /// Interface text.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    /// Book face for the storyteller's words.
    static func story(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: - Surfaces

struct CardStyle: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = Theme.radiusL
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color(hex: 0x1B3A6B).opacity(0.06), radius: 18, x: 0, y: 8)
    }
}

extension View {
    func card(padding: CGFloat = 18, radius: CGFloat = Theme.radiusL) -> some View {
        modifier(CardStyle(padding: padding, radius: radius))
    }
}

/// Faint concentric arcs used as decoration on tiles and cards (as in the reference).
struct RippleDecoration: View {
    var color: Color = Theme.blue
    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width, y: 0)
            for i in 1...5 {
                let r = CGFloat(i) * 18
                var p = Path()
                p.addArc(center: center, radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
                ctx.stroke(p, with: .color(color.opacity(0.08)), lineWidth: 1.2)
            }
        }
        .allowsHitTesting(false)
    }
}
