import SwiftUI

@main
struct MemoireApp: App {
    @State private var app = AppState()
    @State private var purchases = PurchaseManager.shared
    @State private var player = AudioPlayer.shared

    init() {
        PurchaseManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(purchases)
                .environment(player)
                .preferredColorScheme(.light)
                .tint(Theme.blue)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack(alignment: .top) {
            if app.hasOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
            if let toast = app.toast {
                Toast(text: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: app.hasOnboarded)
    }
}

// MARK: - Tabs

struct MainTabView: View {
    @Environment(AppState.self) private var app
    @Environment(AudioPlayer.self) private var player

    var body: some View {
        @Bindable var app = app
        ZStack(alignment: .bottom) {
            Group {
                switch app.selectedTab {
                case .home: HomeView()
                case .stories: StoriesView()
                case .ask: AskView()
                case .family: FamilyView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: player.story != nil ? 150 : 84) }

            VStack(spacing: 10) {
                if player.story != nil { MiniPlayer().padding(.horizontal, 14) }
                TabBar(selection: $app.selectedTab)
            }
        }
        .background(Theme.canvas.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .sheet(item: $app.presentedStory) { story in
            StoryPlayerView(story: story)
        }
        .sheet(isPresented: $app.showPaywall) {
            PaywallView(context: .upgrade)
        }
        .fullScreenCover(isPresented: $app.showLiveCall) {
            LiveCallView()
        }
    }
}

struct TabBar: View {
    @Binding var selection: AppState.Tab
    private let items: [(AppState.Tab, String, String)] = [
        (.home, "house.fill", "Home"),
        (.stories, "book.pages.fill", "Stories"),
        (.ask, "waveform.and.magnifyingglass", "Ask"),
        (.family, "person.3.fill", "Family"),
        (.profile, "person.crop.circle", "Account"),
    ]
    var body: some View {
        HStack {
            ForEach(items, id: \.0) { tab, icon, label in
                Button {
                    withAnimation(.spring(duration: 0.3)) { selection = tab }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: selection == tab ? .semibold : .regular))
                            .symbolEffect(.bounce, value: selection == tab)
                        Text(label).font(.ui(11, selection == tab ? .semibold : .medium))
                    }
                    .foregroundStyle(selection == tab ? Theme.blue : Theme.mute)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(
            Color.white
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
                .shadow(color: Color(hex: 0x1B3A6B).opacity(0.08), radius: 20, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct MiniPlayer: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(AppState.self) private var app
    var body: some View {
        if let story = player.story {
            HStack(spacing: 12) {
                IconBadge(systemName: story.themeStyle.symbol, tint: .white, wash: .white.opacity(0.2), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(story.title).font(.ui(14, .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text("\(app.storytellerFirstName) · \(player.currentTime.clock) / \(player.duration.clock)")
                        .font(.ui(12)).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Button { player.toggle(story) } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.blue)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.white))
                }
                Button { player.stop() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.cardGradient)
                    .overlay(alignment: .bottomLeading) {
                        GeometryReader { g in
                            Capsule().fill(.white.opacity(0.85)).frame(width: g.size.width * player.progress, height: 3)
                        }.frame(height: 3).padding(.horizontal, 18).padding(.bottom, 4)
                    }
            )
            .shadow(color: Theme.blue.opacity(0.3), radius: 16, y: 6)
            .contentShape(Rectangle())
            .onTapGesture { app.presentedStory = story }
        }
    }
}
