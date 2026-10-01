import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var app
    @Environment(AudioPlayer.self) private var player
    @Environment(PurchaseManager.self) private var purchases
    @State private var askingQuestion = false
    @State private var showPlan = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                nextCallCard
                HStack(spacing: 14) {
                    actionTile("Try a call", "Talk with \(app.profile.biographer) now", "phone.fill", Theme.green, Theme.greenWash) {
                        app.showLiveCall = true
                    }
                    actionTile("Ask her", "Her real voice answers", "waveform", Theme.orange, Theme.orangeWash) {
                        app.selectedTab = .ask
                    }
                }
                if !purchases.isFamilyActive { unlockBanner }
                featuredCard(app.story("deux-cv") ?? app.latestStory)
                questionsSection
                latestSection
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas.ignoresSafeArea())
        .sheet(isPresented: $askingQuestion) { AddQuestionSheet().presentationDetents([.height(380)]) }
        .sheet(isPresented: $showPlan) { CallPlanSheet().presentationDetents([.medium, .large]) }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Avatar(person: app.me.spec, size: 48, ring: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hello, Claire").font(.display(19, .semibold)).foregroundStyle(Theme.ink)
                HStack(spacing: 5) {
                    Image(systemName: "person.3.fill").font(.system(size: 11))
                    Text("Morel family · \(app.family.count) listening")
                }
                .font(.ui(13)).foregroundStyle(Theme.mute)
            }
            Spacer()
            CircleIconButton(systemName: "bell", size: 44) { app.flash("Max two notifications a week. Promise.") }
                .overlay(alignment: .topTrailing) { Circle().fill(Theme.orange).frame(width: 9).offset(x: -9, y: 9) }
        }
    }

    // MARK: Next call card

    private var nextCallCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Next call").font(.ui(14, .medium)).opacity(0.85)
                Text(app.nextCallDate.formatted(.dateTime.weekday(.wide).hour().minute()))
                    .font(.display(30, .bold))
                Text("\(app.callName) · with \(app.profile.biographer) · call \(app.stories.map(\.call).max().map { $0 + 1 } ?? 1) of 52")
                    .font(.ui(14)).opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Button { askingQuestion = true } label: {
                    Label("Add a question", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(fill: .white.opacity(0.95)))
                Button { showPlan = true } label: {
                    Label("Louise's plan", systemImage: "sparkles").frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(fill: .white.opacity(0.2), text: .white))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusXL, style: .continuous).fill(Theme.cardGradient)
                .overlay(RippleDecoration(color: .white).clipShape(RoundedRectangle(cornerRadius: Theme.radiusXL)))
        )
        .shadow(color: Theme.blue.opacity(0.28), radius: 20, y: 10)
    }

    private func actionTile(_ title: String, _ sub: String, _ icon: String, _ tint: Color, _ wash: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                IconBadge(systemName: icon, tint: tint, wash: wash, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.display(16, .semibold)).foregroundStyle(Theme.ink)
                    Text(sub).font(.ui(13)).foregroundStyle(Theme.mute).lineLimit(1).minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 16)
            .overlay(alignment: .topTrailing) { RippleDecoration(color: Theme.ink).frame(width: 90, height: 90).clipShape(RoundedRectangle(cornerRadius: Theme.radiusL)) }
        }
        .buttonStyle(.plain)
    }

    private var unlockBanner: some View {
        Button { app.showPaywall = true } label: {
            HStack(spacing: 12) {
                IconBadge(systemName: "gift.fill", tint: Theme.purple, wash: Theme.purpleWash, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome call is free").font(.ui(15, .semibold)).foregroundStyle(Theme.ink)
                    Text("Unlock 52 calls and the voice archive").font(.ui(13)).foregroundStyle(Theme.mute)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.mute)
            }
            .card(padding: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: Featured (promo-style card)

    private func featuredCard(_ story: Story) -> some View {
        let playing = player.isCurrent(story) && player.isPlaying
        return VStack(alignment: .leading, spacing: 10) {
            Text("New this Sunday").font(.ui(13, .medium)).opacity(0.9)
            Text(story.title).font(.display(22, .bold)).fixedSize(horizontal: false, vertical: true)
            if let asker = story.askedBy {
                Text("\(asker) added a photo. \(app.storytellerFirstName) told the whole story.")
                    .font(.ui(14)).opacity(0.9)
            }
            WaveformBars(progress: player.isCurrent(story) ? player.progress : 0, barCount: 34, seed: 3, active: .white, inactive: .white.opacity(0.35))
                .frame(height: 30)
                .padding(.vertical, 4)
            HStack {
                Button { player.toggle(story) } label: {
                    Label(playing ? "Pause" : "Listen · \(story.duration.clock)", systemImage: playing ? "pause.fill" : "play.fill")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(PillButtonStyle())
                Spacer()
                reactionStack(story)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: Theme.radiusXL, style: .continuous).fill(Theme.cardGradient)
                Image(systemName: "car.side.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.white.opacity(0.12))
                    .offset(x: 30, y: -40)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusXL, style: .continuous))
        )
        .shadow(color: Theme.blue.opacity(0.25), radius: 18, y: 8)
        .onTapGesture { app.presentedStory = story }
    }

    private func reactionStack(_ story: Story) -> some View {
        let reactions = app.reactions[story.id] ?? []
        return HStack(spacing: -8) {
            ForEach(reactions.prefix(3)) { r in
                Text(r.emoji).font(.system(size: 15))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white))
                    .overlay(Circle().stroke(Theme.blue.opacity(0.2), lineWidth: 1))
            }
        }
    }

    // MARK: Questions

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Questions for Sunday", action: "Add") { askingQuestion = true }
            VStack(spacing: 0) {
                let open = app.questions.filter { $0.answeredStoryID == nil }.sorted { $0.votes > $1.votes }
                ForEach(Array(open.prefix(3).enumerated()), id: \.element.id) { i, q in
                    HStack(spacing: 12) {
                        Avatar(person: member(q.author), size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(q.text).font(.ui(15, .medium)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                            Text(i == 0 ? "\(q.author) · Louise will ask this one" : q.author)
                                .font(.ui(12)).foregroundStyle(i == 0 ? Theme.blue : Theme.mute)
                        }
                        Spacer()
                        Button { withAnimation(.spring) { app.toggleVote(q) } } label: {
                            VStack(spacing: 0) {
                                Image(systemName: "arrowtriangle.up.fill").font(.system(size: 11))
                                Text("\(q.votes)").font(.ui(13, .bold)).contentTransition(.numericText())
                            }
                            .foregroundStyle(q.voted ? .white : Theme.blue)
                            .frame(width: 40, height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(q.voted ? AnyShapeStyle(Theme.cardGradient) : AnyShapeStyle(Theme.blueWash)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 12)
                    if i < min(open.count, 3) - 1 { Divider().overlay(Theme.hairline) }
                }
            }
            .card(padding: 16)
        }
    }

    private func member(_ first: String) -> AvatarSpec {
        app.family.first { $0.name.hasPrefix(first) }?.spec ?? AvatarSpec(name: first)
    }

    // MARK: Latest stories

    private var latestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Latest stories", action: "View all") { app.selectedTab = .stories }
            ForEach(app.stories.prefix(4)) { story in
                StoryRow(story: story)
            }
        }
        .padding(.bottom, 20)
    }
}

struct StoryRow: View {
    @Environment(AppState.self) private var app
    @Environment(AudioPlayer.self) private var player
    let story: Story
    var body: some View {
        let playing = player.isCurrent(story) && player.isPlaying
        HStack(spacing: 14) {
            IconBadge(systemName: story.themeStyle.symbol, tint: story.themeStyle.tint, wash: story.themeStyle.wash, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(story.title).font(.ui(16, .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                HStack(spacing: 6) {
                    Text(story.theme)
                    Text("·")
                    Text(story.year > 0 ? "\(story.year)" : "Today")
                    Text("·")
                    Text(story.duration.clock)
                    if story.isLiveRecording {
                        Text("LIVE CALL").font(.ui(10, .bold)).foregroundStyle(Theme.green)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Theme.greenWash))
                    }
                }
                .font(.ui(13)).foregroundStyle(Theme.mute)
            }
            Spacer()
            Button { player.toggle(story) } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(playing ? .white : Theme.blue)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(playing ? AnyShapeStyle(Theme.cardGradient) : AnyShapeStyle(Theme.blueWash)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playing ? "Pause" : "Play \(story.title)")
        }
        .card(padding: 14)
        .contentShape(Rectangle())
        .onTapGesture { app.presentedStory = story }
    }
}

// MARK: - Sheets

struct AddQuestionSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ask \(app.callName) something").font(.display(21, .semibold)).foregroundStyle(Theme.ink)
            Text("Louise picks the most-voted question each Sunday and tells her who asked.")
                .font(.ui(14)).foregroundStyle(Theme.mute)
            TextField("Ask about the farm in Tlemcen…", text: $text, axis: .vertical)
                .font(.story(18))
                .lineLimit(3...5)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: Theme.radiusM).fill(Theme.blueWash))
                .focused($focused)
            Button("Add to Sunday's call") {
                let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                app.addQuestion(t)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(Theme.gutter)
        .padding(.top, 8)
        .onAppear { focused = true }
    }
}

struct CallPlanSheet: View {
    @Environment(AppState.self) private var app
    @State private var plan: String?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    IconBadge(systemName: "sparkles", tint: Theme.purple, wash: Theme.purpleWash, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Louise's plan for Sunday").font(.display(19, .semibold)).foregroundStyle(Theme.ink)
                        Text("Prepared from \(app.storytellerFirstName)'s living dossier · Gemini 3.8 Flash, high thinking")
                            .font(.ui(12)).foregroundStyle(Theme.mute)
                    }
                }
                if let plan {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(plan.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.enumerated()), id: \.offset) { i, line in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(i + 1)").font(.ui(13, .bold)).foregroundStyle(.white)
                                    .frame(width: 24, height: 24).background(Circle().fill(Theme.cardGradient))
                                Text(line.replacingOccurrences(of: #"^\d+[\)\.]\s*"#, with: "", options: .regularExpression))
                                    .font(.ui(15)).foregroundStyle(Theme.inkSoft)
                            }
                        }
                    }
                    .card()
                } else if let error {
                    Text(error).font(.ui(14)).foregroundStyle(Theme.mute).card()
                } else {
                    HStack(spacing: 12) { ProgressView(); Text("Louise is reading the dossier…").font(.ui(15)).foregroundStyle(Theme.mute) }
                        .frame(maxWidth: .infinity).card()
                }
                dossier
            }
            .padding(Theme.gutter)
        }
        .background(Theme.canvas)
        .task { await load() }
    }

    private var dossier: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Living dossier").font(.display(16, .semibold)).foregroundStyle(Theme.ink)
            row("person.2.fill", "People", Set(app.stories.flatMap(\.people)).sorted().joined(separator: ", "))
            row("map.fill", "Places", app.profile.places)
            row("checkmark.circle.fill", "Covered", app.stories.map(\.theme).uniqued().joined(separator: ", "))
            row("hand.raised.fill", "Never raise", app.profile.avoid.joined(separator: ", "))
        }
        .card()
    }

    private func row(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.blue).frame(width: 20)
            Text(title).font(.ui(14, .semibold)).foregroundStyle(Theme.ink).frame(width: 82, alignment: .leading)
            Text(value).font(.ui(14)).foregroundStyle(Theme.inkSoft)
        }
    }

    private func load() async {
        let q = app.nextQuestion
        let dossier = """
        Storyteller: \(app.profile.firstName), \(app.profile.relation.lowercased()) of Claire, born \(app.profile.birthYear) in \(app.profile.birthPlace). Work: \(app.profile.career). Places: \(app.profile.places). Family: \(app.profile.family).
        Sensitive topics (never raise): \(app.profile.avoid.joined(separator: "; ")).
        Stories already told: \(app.stories.map { "\($0.title) — \($0.excerpt)" }.joined(separator: " | "))
        Family question with most votes: \(q.map { "\($0.author): \($0.text)" } ?? "none")
        """
        do { plan = try await GeminiText.callPlan(dossier: dossier) }
        catch {
            plan = """
            1) “Good afternoon \(app.profile.firstName), it's Louise, on behalf of Claire. How was your week?”
            2) Last time you told me about the blue 2CV and the farmer's tractor — did you ever make it to Collioure?
            3) Today: school days in Oran. “What did your satchel smell like on the first day of school?”
            4) Follow-ups: the teacher's name; the walk from Rue d'Arzew to school with Simone.
            5) \(q.map { "\($0.author) asks: “\($0.text)”" } ?? "No family question this week.")
            """
            self.error = nil
        }
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] { var seen = Set<Element>(); return filter { seen.insert($0).inserted } }
}
