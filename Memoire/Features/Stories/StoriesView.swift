import SwiftUI

/// The living book: chapters by theme, each one a real recording with its transcript.
struct StoriesView: View {
    @Environment(AppState.self) private var app
    @State private var theme: String? = nil

    var filtered: [Story] { app.stories.filter { theme == nil || $0.theme == theme } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stories").font(.display(28, .bold)).foregroundStyle(Theme.ink)
                        Text("\(app.stories.count) stories · \(Int(app.totalListeningTime / 60)) min of \(app.storytellerFirstName)'s voice")
                            .font(.ui(14)).foregroundStyle(Theme.mute)
                    }
                    Spacer()
                }

                bookCard

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button { withAnimation(.spring) { theme = nil } } label: { Chip(text: "All", selected: theme == nil) }
                        ForEach(app.themes, id: \.self) { t in
                            Button { withAnimation(.spring) { theme = t } } label: {
                                Chip(text: t, selected: theme == t, systemName: ThemeStyle.for(t).symbol)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                ForEach(filtered) { story in
                    StoryRow(story: story)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas.ignoresSafeArea())
    }

    private var bookCard: some View {
        let done = Double(app.stories.map(\.call).max() ?? 0)
        return HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x0E5FCF)).frame(width: 74, height: 98).offset(x: 5, y: 4)
                RoundedRectangle(cornerRadius: 6).fill(.white).frame(width: 74, height: 98)
                    .overlay(
                        VStack(spacing: 4) {
                            Text("Jeanne").font(.story(14, .semibold)).foregroundStyle(Theme.ink)
                            Rectangle().fill(Theme.blue).frame(width: 22, height: 1.5)
                            Text("A life,\nin her words").font(.story(8)).multilineTextAlignment(.center).foregroundStyle(Theme.inkSoft)
                        }
                    )
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("The book").font(.display(18, .semibold))
                Text("\(Int(done)) of 52 calls · printed when the year ends, with a QR code to her voice in every chapter.")
                    .font(.ui(13)).opacity(0.9)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(.white).frame(width: g.size.width * done / 52)
                    }
                }
                .frame(height: 6)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: Theme.radiusXL, style: .continuous).fill(Theme.cardGradient))
        .shadow(color: Theme.blue.opacity(0.25), radius: 18, y: 8)
    }
}

// MARK: - Player with word-synced transcript

struct StoryPlayerView: View {
    let story: Story
    @Environment(AppState.self) private var app
    @Environment(AudioPlayer.self) private var player
    @Environment(\.dismiss) private var dismiss
    @State private var showChapter = false

    var current: Bool { player.isCurrent(story) }
    let emojis = ["❤️", "🥹", "😂", "🤯", "🙏"]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        promptCard
                        if showChapter, let chapter = story.chapter {
                            Text(chapter).font(.story(19)).foregroundStyle(Theme.ink).lineSpacing(7)
                        } else {
                            ForEach(Array(story.segments.enumerated()), id: \.offset) { i, seg in
                                let active = current && player.activeSegmentIndex == i
                                let past = current && (player.activeSegmentIndex ?? -1) > i
                                Text(seg.text)
                                    .font(.story(active ? 23 : 21, active ? .semibold : .regular))
                                    .foregroundStyle(active ? Theme.ink : (past ? Theme.inkSoft.opacity(0.55) : Theme.inkSoft.opacity(current ? 0.45 : 0.9)))
                                    .lineSpacing(5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(i)
                                    .contentShape(Rectangle())
                                    .onTapGesture { player.play(story, from: seg.start) }
                                    .animation(.easeInOut(duration: 0.3), value: active)
                            }
                        }
                        reactionsBlock
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                .onChange(of: player.activeSegmentIndex) { _, i in
                    guard current, let i else { return }
                    withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(i, anchor: .center) }
                }
            }
            controls
        }
        .background(Theme.canvas.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                CircleIconButton(systemName: "chevron.down", size: 40) { dismiss() }
                Spacer()
                VStack(spacing: 2) {
                    Text(story.theme.uppercased()).font(.ui(11, .bold)).foregroundStyle(story.themeStyle.tint).tracking(1)
                    Text("Call \(story.call) · \(story.dateValue.formatted(date: .abbreviated, time: .omitted))")
                        .font(.ui(12)).foregroundStyle(Theme.mute)
                }
                Spacer()
                ShareLink(item: "“\(story.segments.first?.text ?? "")” — \(app.storytellerFirstName), on Mémoire", subject: Text(story.title)) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 40).background(Circle().fill(.white))
                }
            }
            Text(story.title).font(.display(24, .bold)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Label("\(story.place), \(story.year > 0 ? String(story.year) : "")", systemImage: "mappin.and.ellipse")
                if story.chapter != nil {
                    Button(showChapter ? "Transcript" : "Chapter") { withAnimation { showChapter.toggle() } }
                        .font(.ui(12, .semibold)).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Theme.blueWash))
                }
            }
            .font(.ui(13)).foregroundStyle(Theme.mute)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var promptCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(person: AvatarSpec(name: story.askedBy.map { "\($0) M" } ?? "Louise AI", colors: story.askedBy == nil ? [Theme.blueSky, Theme.blue] : [Color(hex: 0xB9A6FF), Theme.purple]), size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(story.askedBy.map { "\($0) asked, through Louise" } ?? "Louise asked")
                    .font(.ui(12, .semibold)).foregroundStyle(Theme.mute)
                Text(story.prompt).font(.ui(15, .medium)).foregroundStyle(Theme.ink)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radiusM).fill(Theme.blueWash))
    }

    private var reactionsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Family").font(.display(16, .semibold)).foregroundStyle(Theme.ink).padding(.top, 12)
            ForEach(app.reactions[story.id] ?? []) { r in
                HStack(spacing: 10) {
                    Text(r.emoji).font(.system(size: 20))
                    Text(r.author).font(.ui(14, .semibold)).foregroundStyle(Theme.ink)
                    if !r.text.isEmpty { Text(r.text).font(.ui(14)).foregroundStyle(Theme.inkSoft) }
                }
            }
            HStack(spacing: 10) {
                ForEach(emojis, id: \.self) { e in
                    let mine = app.reactions[story.id]?.contains { $0.author == "Claire" && $0.emoji == e } == true
                    Button { withAnimation(.spring) { app.react(to: story, emoji: e) } } label: {
                        Text(e).font(.system(size: 22)).frame(width: 48, height: 48)
                            .background(Circle().fill(mine ? Theme.blueMist : .white))
                            .scaleEffect(mine ? 1.1 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            Label("Real recording. Mémoire never synthesises a storyteller's voice.", systemImage: "checkmark.seal.fill")
                .font(.ui(12)).foregroundStyle(Theme.mute).padding(.top, 6)
            if story.voice == "say" || story.voice == "gemini" {
                Text("Hackathon demo: this sample story was voiced by a TTS actress.")
                    .font(.ui(11)).foregroundStyle(Theme.mute.opacity(0.8))
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                WaveformBars(progress: current ? player.progress : 0, barCount: 52, seed: story.id.count)
                    .frame(height: 34)
                    .overlay(GeometryReader { g in
                        Color.clear.contentShape(Rectangle()).onTapGesture { location in
                            let t = Double(location.x / g.size.width) * (current ? player.duration : story.duration)
                            player.play(story, from: t)
                        }
                    })
                HStack {
                    Text((current ? player.currentTime : 0).clock)
                    Spacer()
                    Text(story.duration.clock)
                }
                .font(.ui(12, .medium)).foregroundStyle(Theme.mute).monospacedDigit()
            }
            HStack(spacing: 34) {
                Button { player.skip(-10) } label: { Image(systemName: "gobackward.10").font(.system(size: 24)) }
                Button { player.toggle(story) } label: {
                    Image(systemName: current && player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 74)
                        .background(Circle().fill(Theme.cardGradient))
                        .shadow(color: Theme.blue.opacity(0.35), radius: 14, y: 6)
                }
                Button { player.skip(10) } label: { Image(systemName: "goforward.10").font(.system(size: 24)) }
            }
            .foregroundStyle(Theme.ink)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(
            Color.white.clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 20, y: -6)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
