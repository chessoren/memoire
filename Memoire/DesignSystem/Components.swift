import SwiftUI

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var dark = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(17, .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                Capsule().fill(dark ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(Theme.cardGradient))
            )
            .shadow(color: (dark ? Color.black : Theme.blue).opacity(0.25), radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct PillButtonStyle: ButtonStyle {
    var fill: Color = .white
    var text: Color = Theme.blue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(15, .semibold))
            .foregroundStyle(text)
            .padding(.horizontal, 20)
            .frame(height: 46)
            .background(Capsule().fill(fill))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct CircleIconButton: View {
    let systemName: String
    var tint: Color = Theme.ink
    var background: Color = .white
    var size: CGFloat = 44
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(background))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon tile (pastel square with glyph)

struct IconBadge: View {
    let systemName: String
    var tint: Color = Theme.green
    var wash: Color = Theme.greenWash
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous).fill(wash))
    }
}

// MARK: - Avatar

struct Avatar: View {
    let person: AvatarSpec
    var size: CGFloat = 44
    var ring: Bool = false
    var body: some View {
        ZStack {
            if let image = person.imageName, UIImage(named: image) != nil {
                Image(image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: person.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(person.initials)
                    .font(.display(size * 0.36, .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: ring ? max(2, size * 0.05) : 0))
        .shadow(color: .black.opacity(ring ? 0.12 : 0), radius: 8, y: 4)
        .accessibilityLabel(person.name)
    }
}

struct AvatarSpec: Hashable {
    let name: String
    var imageName: String? = nil
    var colors: [Color] = [Theme.blueSky, Theme.blue]
    var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.display(19, .semibold)).foregroundStyle(Theme.ink)
            Spacer()
            if let action {
                Button(action) { onAction?() }
                    .font(.ui(15, .medium))
                    .foregroundStyle(Theme.mute)
            }
        }
    }
}

// MARK: - Chips

struct Chip: View {
    let text: String
    var selected: Bool
    var systemName: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let systemName { Image(systemName: systemName).font(.system(size: 13, weight: .semibold)) }
            Text(text).font(.ui(14, .medium))
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .foregroundStyle(selected ? .white : Theme.inkSoft)
        .background(Capsule().fill(selected ? AnyShapeStyle(Theme.cardGradient) : AnyShapeStyle(Color.white)))
        .overlay(Capsule().stroke(selected ? .clear : Theme.hairline, lineWidth: 1))
    }
}

// MARK: - Page dots (onboarding)

struct PageDots: View {
    let count: Int
    let index: Int
    var activeColor: Color = Theme.ink
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? activeColor : Theme.mute.opacity(0.3))
                    .frame(width: i == index ? 26 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.35), value: index)
    }
}

// MARK: - Waveform

struct WaveformBars: View {
    var progress: Double = 0
    var barCount: Int = 42
    var seed: Int = 7
    var active: Color = Theme.blue
    var inactive: Color = Theme.blueMist
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { i in
                    let h = Self.height(i, seed: seed)
                    Capsule()
                        .fill(Double(i) / Double(barCount) <= progress ? active : inactive)
                        .frame(height: max(4, geo.size.height * h))
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
    static func height(_ i: Int, seed: Int) -> CGFloat {
        let x = Double(i * 31 + seed * 17)
        let v = (sin(x * 0.37) + sin(x * 0.11 + 1.3) + 2) / 4
        return CGFloat(0.18 + 0.82 * v)
    }
}

/// Live, animated waveform driven by an audio level (0...1).
struct LiveWave: View {
    var level: Double
    var color: Color = .white
    var bars = 5
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<bars, id: \.self) { i in
                    let wobble = (sin(t * 7 + Double(i) * 1.1) + 1) / 2
                    Capsule()
                        .fill(color)
                        .frame(width: 4, height: 6 + 26 * CGFloat(max(0.08, level) * (0.4 + 0.6 * wobble)))
                }
            }
        }
    }
}

// MARK: - Phone mockup (onboarding illustrations)

struct PhoneMockup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(Theme.ink)
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(Theme.heroGradient)
                .overlay(content.clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous)))
                .padding(7)
            Capsule().fill(Theme.ink).frame(width: 96, height: 28).padding(.top, 18)
        }
        .mask(
            LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.72), .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - Toast

struct Toast: View {
    let text: String
    var systemName = "checkmark.circle.fill"
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemName).foregroundStyle(Theme.green)
            Text(text).font(.ui(15, .medium)).foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(Capsule().fill(.white))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }
}

// MARK: - Back button

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var light = false
    var body: some View {
        CircleIconButton(systemName: "chevron.left",
                         tint: light ? .white : Theme.ink,
                         background: light ? .white.opacity(0.22) : .white,
                         size: 42) { dismiss() }
    }
}

// MARK: - Settings row

struct SettingsRow: View {
    let systemName: String
    let title: String
    var detail: String? = nil
    var tint: Color = Theme.inkSoft
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 26)
            Text(title).font(.ui(16, .medium)).foregroundStyle(Theme.ink)
            Spacer()
            if let detail { Text(detail).font(.ui(14)).foregroundStyle(Theme.mute) }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mute)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Formatting

extension TimeInterval {
    var clock: String {
        let s = Int(self.rounded(.down))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
