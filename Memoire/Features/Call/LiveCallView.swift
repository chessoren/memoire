import SwiftUI

/// A real conversation with Louise (Gemini Live). In production Louise calls the
/// storyteller's phone line; here the family can try her first-hand. When the
/// call ends, the post-call pipeline turns it into a story in the archive.
struct LiveCallView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var session = GeminiLiveSession()
    @State private var now = Date()
    @State private var muted = false
    @State private var phase: Phase = .call
    @State private var pipelineStep = 0
    @State private var result: Story?
    @State private var pipelineError: String?

    enum Phase { case call, processing, done }

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.callGradient.ignoresSafeArea()
            switch phase {
            case .call: callScreen
            case .processing, .done: pipelineScreen
            }
        }
        .onReceive(ticker) { now = $0 }
        .task {
            AudioPlayer.shared.stop()
            let prompt = Biographer.systemPrompt(profile: app.profile, stories: app.stories, question: app.nextQuestion, buyer: "Claire")
            await session.start(systemPrompt: prompt, kickoff: Biographer.kickoff(profile: app.profile), voice: Config.biographerVoice)
        }
        .onDisappear { session.end() }
    }

    // MARK: Call

    private var elapsed: TimeInterval { session.startedAt.map { now.timeIntervalSince($0) } ?? 0 }

    private var callScreen: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemName: "chevron.down", tint: .white, background: .white.opacity(0.2), size: 40) { hangUp() }
                Spacer()
                Label("Test call", systemImage: "flask.fill").font(.ui(13, .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(height: 32).background(Capsule().fill(.white.opacity(0.2)))
            }
            .padding(.horizontal, Theme.gutter)

            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(.white.opacity(0.14)).frame(width: 150, height: 150)
                        .scaleEffect(1 + CGFloat(session.outputLevel) * 0.25)
                    Circle().fill(.white.opacity(0.22)).frame(width: 122, height: 122)
                        .scaleEffect(1 + CGFloat(session.outputLevel) * 0.12)
                    Avatar(person: AvatarSpec(name: "Louise", colors: [Color(hex: 0x9FD0FF), Theme.blueDeep]), size: 98, ring: true)
                }
                .animation(.easeOut(duration: 0.12), value: session.outputLevel)
                .padding(.top, 18)
                Text("\(app.profile.biographer) · Mémoire").font(.display(22, .semibold)).foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text("AI biographer").font(.ui(12, .bold))
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(.white.opacity(0.22)))
                    Text(statusText).font(.ui(14, .medium)).monospacedDigit()
                }
                .foregroundStyle(.white.opacity(0.95))
            }

            transcript
                .padding(.top, 18)

            controls
        }
    }

    private var statusText: String {
        switch session.state {
        case .idle, .connecting: "Calling…"
        case .live: elapsed.clock
        case .ended: "Call ended"
        case .failed: "Couldn't connect"
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if case .failed(let msg) = session.state {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Louise can't take this call", systemImage: "exclamationmark.triangle.fill")
                                .font(.ui(15, .semibold)).foregroundStyle(Theme.ink)
                            Text(msg).font(.ui(14)).foregroundStyle(Theme.inkSoft)
                        }
                        .card()
                    }
                    ForEach(session.lines) { line in
                        let isLouise = line.speaker == .biographer
                        VStack(alignment: isLouise ? .leading : .trailing, spacing: 4) {
                            Text(isLouise ? app.profile.biographer : "You, as \(app.storytellerFirstName)")
                                .font(.ui(11, .semibold)).foregroundStyle(Theme.mute)
                            Text(line.text.trimmingCharacters(in: .whitespaces))
                                .font(isLouise ? .ui(16) : .story(17))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isLouise ? .white : Theme.blueWash))
                        }
                        .frame(maxWidth: .infinity, alignment: isLouise ? .leading : .trailing)
                        .id(line.id)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    if session.state == .live && session.lines.isEmpty {
                        HStack { Spacer(); LiveWave(level: 0.4, color: Theme.blue).frame(height: 30); Spacer() }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 12)
                .animation(.spring(duration: 0.35), value: session.lines.count)
            }
            .scrollIndicators(.hidden)
            .onChange(of: session.lines.last?.text) { _, _ in
                if let id = session.lines.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                pill(muted ? "mic.slash.fill" : "mic.fill", active: muted) { muted.toggle(); session.setMuted(muted) }
                pill("captions.bubble.fill", active: true) { }
                pill("speaker.wave.2.fill", active: false) { }
            }
            .overlay(alignment: .top) {
                if session.state == .live {
                    HStack(spacing: 6) {
                        LiveWave(level: Double(session.inputLevel), color: Theme.blue, bars: 4).frame(height: 24)
                        Text("Listening patiently — take your time").font(.ui(12, .medium)).foregroundStyle(Theme.mute)
                    }
                    .offset(y: -34)
                }
            }
            Button(action: hangUp) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 58)
                    .background(Capsule().fill(Theme.red))
                    .shadow(color: Theme.red.opacity(0.35), radius: 14, y: 6)
            }
            .accessibilityLabel("End call")
        }
        .padding(.top, 40)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(Theme.canvas.opacity(0.92).ignoresSafeArea())
    }

    private func pill(_ icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 19, weight: .medium))
                .foregroundStyle(active ? .white : Theme.ink)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Capsule().fill(active ? AnyShapeStyle(Theme.cardGradient) : AnyShapeStyle(Color.white)))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 2)
        .frame(maxWidth: 110)
    }

    // MARK: Hang up → pipeline

    private func hangUp() {
        let turns = session.storytellerTurns.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        session.end()
        guard !turns.isEmpty, let rec = session.recordingURL else { dismiss(); return }
        withAnimation(.spring) { phase = .processing }
        Task { await runPipeline(turns: turns, recording: rec) }
    }

    private func runPipeline(turns: [GeminiLiveSession.Turn], recording: URL) async {
        let transcript = session.lines.map { "\($0.speaker == .biographer ? app.profile.biographer : app.storytellerFirstName): \($0.text)" }.joined(separator: "\n")
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation { pipelineStep = 1 }   // transcribed
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation { pipelineStep = 2 }   // writing
        do {
            let r = try await GeminiText.writeChapter(transcript: transcript, storyteller: app.storytellerFirstName)
            withAnimation { pipelineStep = 3 }
            let segments = turns.map { Segment(text: $0.text.trimmingCharacters(in: .whitespaces), start: $0.start, end: max($0.end, $0.start + 1)) }
            let duration = segments.last?.end ?? 0
            var story = Story(id: "live-\(Int(Date().timeIntervalSince1970))", title: r.title, theme: r.theme, year: r.year,
                              place: r.place.isEmpty ? app.profile.birthPlace : r.place,
                              call: (app.stories.map(\.call).max() ?? 0) + 1,
                              date: ISO8601DateFormatter().string(from: .now).prefix(10).description,
                              prompt: session.lines.first { $0.speaker == .biographer }?.text ?? "",
                              askedBy: nil, people: r.people, highlight: true, segments: segments,
                              duration: duration + 0.5, audio: recording.lastPathComponent, voice: "live")
            story.chapter = r.chapter
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation { pipelineStep = 4 }
            app.addRecordedStory(story)
            result = story
            withAnimation(.spring) { phase = .done }
        } catch {
            // Never lose a recording: keep the verbatim call, the chapter can be written later.
            let segments = turns.map { Segment(text: $0.text.trimmingCharacters(in: .whitespaces), start: $0.start, end: max($0.end, $0.start + 1)) }
            let story = Story(id: "live-\(Int(Date().timeIntervalSince1970))", title: "\(app.profile.day)'s call", theme: "Family", year: 0,
                              place: app.profile.birthPlace, call: (app.stories.map(\.call).max() ?? 0) + 1,
                              date: ISO8601DateFormatter().string(from: .now).prefix(10).description,
                              prompt: session.lines.first { $0.speaker == .biographer }?.text ?? "",
                              askedBy: nil, people: [], highlight: false, segments: segments,
                              duration: (segments.last?.end ?? 0) + 0.5, audio: recording.lastPathComponent, voice: "live")
            app.addRecordedStory(story)
            pipelineError = "Recording saved. The chapter will be written when Gemini is available (\(error.localizedDescription))."
            withAnimation(.spring) { phase = .done }
        }
    }

    private var pipelineScreen: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(.white).frame(width: 110, height: 110).shadow(color: Theme.blue.opacity(0.25), radius: 20, y: 8)
                Image(systemName: phase == .done && pipelineError == nil ? "book.pages.fill" : "sparkles")
                    .font(.system(size: 42)).foregroundStyle(Theme.blue)
                    .symbolEffect(.pulse, isActive: phase == .processing)
            }
            Text(phase == .done ? (pipelineError == nil ? "A new chapter" : "Saved for later") : "Writing the chapter…")
                .font(.display(24, .bold)).foregroundStyle(Theme.ink)

            VStack(alignment: .leading, spacing: 14) {
                step(0, "Call recorded, \(app.storytellerFirstName)'s voice kept")
                step(1, "Transcribed with speaker separation")
                step(2, "Chapter written in her own words · Gemini 3.8 Flash")
                step(3, "People, places and dates added to the dossier")
                step(4, "Family notified")
            }
            .card(padding: 20)
            .padding(.horizontal, Theme.gutter)

            if let r = result {
                VStack(alignment: .leading, spacing: 8) {
                    Text(r.title).font(.display(18, .semibold)).foregroundStyle(Theme.ink)
                    Text(r.chapter ?? "").font(.story(15)).foregroundStyle(Theme.inkSoft).lineLimit(4)
                }
                .card()
                .padding(.horizontal, Theme.gutter)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let pipelineError {
                Text(pipelineError).font(.ui(13)).foregroundStyle(Theme.mute).padding(.horizontal, 30).multilineTextAlignment(.center)
            }
            Spacer()
            if phase == .done {
                Button(result != nil ? "Listen to the new story" : "Close") {
                    if let r = result { app.selectedTab = .stories; dismiss(); Task { try? await Task.sleep(for: .milliseconds(500)); app.presentedStory = r } }
                    else { dismiss() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 10)
            }
        }
    }

    private func step(_ i: Int, _ text: String) -> some View {
        let done = pipelineStep > i || phase == .done && pipelineError == nil
        let current = pipelineStep == i && phase == .processing
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(done ? AnyShapeStyle(Theme.cardGradient) : AnyShapeStyle(Theme.blueWash)).frame(width: 26, height: 26)
                if done { Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white) }
                else if current { ProgressView().scaleEffect(0.6) }
            }
            Text(text).font(.ui(15, done ? .medium : .regular)).foregroundStyle(done ? Theme.ink : Theme.mute)
        }
    }
}
