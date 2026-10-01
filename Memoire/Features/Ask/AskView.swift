import SwiftUI

/// The voice archive: ask in plain words, hear the real passages where she tells it.
struct AskView: View {
    @Environment(AppState.self) private var app
    @Environment(AudioPlayer.self) private var player
    @State private var query = ""
    @State private var asked = ""
    @State private var hits: [ArchiveHit] = []
    @State private var searching = false
    @FocusState private var focused: Bool

    private let suggestions = [
        "How did Grandma meet Grandpa?",
        "What was her first job?",
        "Did Grandpa do anything crazy?",
        "What did her kitchen smell like?",
        "The day Mum was born",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ask \(app.storytellerFirstName)").font(.display(28, .bold)).foregroundStyle(Theme.ink)
                    Text("Ask anything. Her own voice answers — real recordings, never a synthetic copy.")
                        .font(.ui(15)).foregroundStyle(Theme.mute)
                }

                searchBar

                if hits.isEmpty && !searching {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Try").font(.ui(13, .semibold)).foregroundStyle(Theme.mute)
                        ForEach(suggestions, id: \.self) { s in
                            Button { query = s; run() } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "text.bubble").foregroundStyle(Theme.blue)
                                    Text(s).font(.ui(15, .medium)).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.system(size: 13)).foregroundStyle(Theme.mute)
                                }
                                .card(padding: 16, radius: Theme.radiusM)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    privacyNote
                } else if searching {
                    HStack(spacing: 10) { ProgressView(); Text("Listening through \(app.stories.count) stories…").font(.ui(15)).foregroundStyle(Theme.mute) }
                        .frame(maxWidth: .infinity).padding(.top, 30)
                } else {
                    Text("“\(asked)”").font(.story(20).italic()).foregroundStyle(Theme.inkSoft)
                    ForEach(Array(hits.enumerated()), id: \.element.id) { i, hit in
                        AnswerCard(hit: hit, primary: i == 0)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    Button("Not quite? Ask \(app.profile.biographer) to bring it up on Sunday") {
                        app.addQuestion(asked)
                    }
                    .font(.ui(14, .semibold)).foregroundStyle(Theme.blue)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 6)
            .padding(.bottom, 20)
            .animation(.spring(duration: 0.45), value: hits)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.canvas.ignoresSafeArea())
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.mute)
            TextField("How did Grandma meet Grandpa?", text: $query)
                .font(.ui(16))
                .focused($focused)
                .submitLabel(.search)
                .onSubmit(run)
            if !query.isEmpty {
                Button { query = ""; hits = [] } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.mute) }
            }
            Button(action: run) {
                Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(Circle().fill(Theme.cardGradient))
            }
            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.leading, 18).padding(.trailing, 8)
        .frame(height: 56)
        .background(Capsule().fill(.white))
        .shadow(color: Color(hex: 0x1B3A6B).opacity(0.06), radius: 14, y: 6)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemName: "iphone.gen3", tint: Theme.purple, wash: Theme.purpleWash, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text("Searched on this iPhone").font(.ui(14, .semibold)).foregroundStyle(Theme.ink)
                Text("Matching runs on-device with Apple's language models. Her stories never leave the family to answer a question.")
                    .font(.ui(13)).foregroundStyle(Theme.mute)
            }
        }
        .card()
    }

    private func run() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        focused = false
        asked = q
        searching = true
        hits = []
        let stories = app.stories
        Task {
            let result = await Task.detached { ArchiveSearch.search(q, in: stories) }.value
            try? await Task.sleep(for: .milliseconds(450))
            searching = false
            hits = result
            if let first = result.first { player.play(first.story, from: first.start, until: first.end) }
        }
    }
}

struct AnswerCard: View {
    let hit: ArchiveHit
    let primary: Bool
    @Environment(AppState.self) private var app
    @Environment(AudioPlayer.self) private var player

    var playingThis: Bool {
        player.isCurrent(hit.story) && player.isPlaying && player.currentTime >= hit.start - 0.2 && player.currentTime <= hit.end + 0.2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                IconBadge(systemName: hit.story.themeStyle.symbol, tint: hit.story.themeStyle.tint, wash: hit.story.themeStyle.wash, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(hit.story.title).font(.ui(14, .semibold)).foregroundStyle(Theme.ink)
                    Text("Call \(hit.story.call) · \(hit.start.clock)–\(hit.end.clock)").font(.ui(12)).foregroundStyle(Theme.mute)
                }
                Spacer()
                if primary {
                    Text("Best match").font(.ui(11, .bold)).foregroundStyle(Theme.green)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(Theme.greenWash))
                }
            }
            Text(attributed)
                .font(.story(primary ? 19 : 17))
                .lineSpacing(5)
            HStack(spacing: 12) {
                Button {
                    if playingThis { player.pause() } else { player.play(hit.story, from: hit.start, until: hit.end) }
                } label: {
                    Label(playingThis ? "Pause" : "Hear her say it", systemImage: playingThis ? "pause.fill" : "play.fill")
                        .font(.ui(14, .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(height: 40)
                        .background(Capsule().fill(Theme.cardGradient))
                }
                .buttonStyle(.plain)
                if playingThis { LiveWave(level: 0.7, color: Theme.blue, bars: 5).frame(height: 30) }
                Spacer()
                Button("Full story") { app.presentedStory = hit.story }
                    .font(.ui(14, .semibold)).foregroundStyle(Theme.blue)
            }
        }
        .card(padding: 18)
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusL).stroke(primary ? Theme.blue.opacity(0.35) : .clear, lineWidth: 1.5))
    }

    /// Highlights the sentence being spoken right now.
    private var attributed: AttributedString {
        var out = AttributedString()
        for i in hit.range {
            let seg = hit.story.segments[i]
            var part = AttributedString(seg.text + " ")
            let speaking = player.isCurrent(hit.story) && player.currentTime >= seg.start && player.currentTime < seg.end + 0.5
            part.foregroundColor = speaking ? Theme.ink : Theme.inkSoft.opacity(0.75)
            if speaking { part.backgroundColor = Theme.blueMist }
            out += part
        }
        return out
    }
}
