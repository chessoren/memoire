import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppState.self) private var app
    @State private var stage: Stage = .intro

    enum Stage: Hashable { case intro, setup, paywall, invite }

    var body: some View {
        ZStack {
            switch stage {
            case .intro:
                IntroPager { withAnimation(.spring) { stage = .setup } }
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            case .setup:
                SetupFlow(onBack: { withAnimation(.spring) { stage = .intro } },
                          onDone: { withAnimation(.spring) { stage = .paywall } })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .paywall:
                PaywallView(context: .onboarding) { withAnimation(.spring) { stage = .invite } }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .invite:
                InviteFamilyView { app.hasOnboarded = true }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(Theme.canvas.ignoresSafeArea())
    }
}

// MARK: - Intro pager (listen first, then explain)

struct IntroPager: View {
    @Environment(AppState.self) private var app
    @Environment(AudioPlayer.self) private var player
    @State private var page = 0
    let onFinish: () -> Void

    private let pages: [(String, String)] = [
        ("Hear Jeanne, 81", "Tap play. This is what Mémoire keeps: a real voice, telling a real memory."),
        ("We call. They just pick up.", "Every Sunday, Louise, a warm AI biographer, calls your parent or grandparent. Nothing to install, no app, no password."),
        ("The whole family joins in", "Everyone gets the story that night, reacts, and slips a question into next Sunday's call."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                PhoneMockup { ListenIllustration() }.tag(0).padding(.horizontal, 36)
                PhoneMockup { CallIllustration() }.tag(1).padding(.horizontal, 36)
                PhoneMockup { FamilyOrbitIllustration() }.tag(2).padding(.horizontal, 36)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .padding(.top, 12)

            VStack(spacing: 14) {
                Text(pages[page].0)
                    .font(.display(25, .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                Text(pages[page].1)
                    .font(.ui(16))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(minHeight: 66, alignment: .top)
                    .contentTransition(.opacity)
                PageDots(count: 3, index: page).padding(.vertical, 8)
                Button(page == 2 ? "Offer Mémoire" : "Next") {
                    if page < 2 { withAnimation(.spring) { page += 1 } } else { player.stop(); onFinish() }
                }
                .buttonStyle(PrimaryButtonStyle(dark: true))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
            .animation(.easeInOut(duration: 0.25), value: page)
        }
        .background(Theme.canvas.ignoresSafeArea())
    }
}

/// Page 1 — the sample memory plays before any marketing text.
struct ListenIllustration: View {
    @Environment(AppState.self) private var app
    @Environment(AudioPlayer.self) private var player
    @State private var pulse = false

    var story: Story { app.story("kitchen") ?? app.latestStory }
    var playing: Bool { player.isCurrent(story) && player.isPlaying }

    var body: some View {
        ZStack {
            ForEach(1..<4) { i in
                Circle().stroke(.white.opacity(0.35), lineWidth: 1)
                    .frame(width: CGFloat(i) * 92, height: CGFloat(i) * 92)
                    .scaleEffect(playing && pulse ? 1.06 : 1)
                    .animation(.easeInOut(duration: 1.6).repeatForever().delay(Double(i) * 0.2), value: pulse)
            }
            VStack(spacing: 18) {
                Button {
                    if player.isCurrent(story) { player.toggle(story) } else { player.play(story, from: 0, until: 16) }
                } label: {
                    ZStack {
                        Circle().fill(.white).frame(width: 96, height: 96)
                            .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Theme.blue)
                            .offset(x: playing ? 0 : 3)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playing ? "Pause sample" : "Play sample memory")

                if player.isCurrent(story), let i = player.activeSegmentIndex {
                    Text("“\(story.segments[i].text)”")
                        .font(.story(16).italic())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 26)
                        .transition(.opacity)
                        .id(i)
                } else {
                    Text("“Oh, the kitchen…”")
                        .font(.story(16).italic())
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .animation(.easeInOut, value: player.activeSegmentIndex)
            orbitDot(.orange, x: 108, y: -132, size: 12)
            orbitDot(.orange, x: -122, y: 40, size: 9)
            orbitDot(.white, x: 70, y: 150, size: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
        .onAppear { pulse = true }
    }

    func orbitDot(_ c: Color, x: CGFloat, y: CGFloat, size: CGFloat) -> some View {
        Circle().fill(c == .orange ? Theme.orange : c).frame(width: size, height: size).offset(x: x, y: y)
    }
}

/// Page 2 — the incoming call the storyteller sees on their own phone.
struct CallIllustration: View {
    @State private var ring = false
    var body: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 50)
            Text("Sunday 3:00 PM").font(.ui(13, .medium)).foregroundStyle(.white.opacity(0.8))
            ZStack {
                Circle().fill(.white.opacity(0.18)).frame(width: 118, height: 118)
                    .scaleEffect(ring ? 1.15 : 0.95)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: ring)
                Circle().fill(.white).frame(width: 88, height: 88)
                Image(systemName: "phone.fill").font(.system(size: 34)).foregroundStyle(Theme.blue)
                    .rotationEffect(.degrees(ring ? -12 : 12))
                    .animation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true), value: ring)
            }
            Text("Louise · Mémoire").font(.display(20, .semibold)).foregroundStyle(.white)
            Text("on behalf of Claire").font(.ui(14)).foregroundStyle(.white.opacity(0.85))
            Spacer()
            HStack(spacing: 54) {
                Circle().fill(Theme.red).frame(width: 62, height: 62)
                    .overlay(Image(systemName: "phone.down.fill").font(.system(size: 22)).foregroundStyle(.white))
                Circle().fill(Theme.green).frame(width: 62, height: 62)
                    .overlay(Image(systemName: "phone.fill").font(.system(size: 22)).foregroundStyle(.white))
            }
            .padding(.bottom, 90)
        }
        .frame(maxWidth: .infinity)
        .onAppear { ring = true }
    }
}

/// Page 3 — the family orbiting around the storyteller.
struct FamilyOrbitIllustration: View {
    @Environment(AppState.self) private var app
    @State private var spin = false
    var body: some View {
        ZStack {
            ForEach(1..<4) { i in
                Circle().stroke(.white.opacity(0.4), lineWidth: 1)
                    .frame(width: CGFloat(i) * 96, height: CGFloat(i) * 96)
            }
            Avatar(person: AvatarSpec(name: "Jeanne Morel", colors: [Color(hex: 0xFFD3A8), Theme.orange]), size: 96, ring: true)
            ZStack {
                ForEach(Array(app.family.prefix(5).enumerated()), id: \.offset) { i, m in
                    let angle = Double(i) / 5 * 2 * .pi
                    let r: CGFloat = i % 2 == 0 ? 144 : 96
                    Avatar(person: m.spec, size: i % 2 == 0 ? 46 : 40, ring: true)
                        .rotationEffect(.degrees(spin ? -360 : 0))
                        .offset(x: cos(angle) * r, y: sin(angle) * r)
                }
                Circle().fill(Theme.orange).frame(width: 11).offset(x: 96, y: -10)
                Circle().fill(Theme.orange).frame(width: 9).offset(x: -60, y: 125)
            }
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 60).repeatForever(autoreverses: false), value: spin)
            bubble("Did Grandpa ever do something crazy?", x: 18, y: -150)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
        .onAppear { spin = true }
    }

    func bubble(_ text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.ui(12, .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(.white))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .offset(x: x, y: y)
    }
}
