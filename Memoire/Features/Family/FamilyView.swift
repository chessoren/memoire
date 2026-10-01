import SwiftUI

/// People she talks about, and the timeline of her life — built from the calls.
struct FamilyView: View {
    @Environment(AppState.self) private var app
    @State private var mode = 0
    @State private var selected: PersonNode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(app.storytellerFirstName)'s world").font(.display(28, .bold)).foregroundStyle(Theme.ink)
                    Text("Built automatically from every call").font(.ui(14)).foregroundStyle(Theme.mute)
                }
                segmented
                if mode == 0 { peopleSection } else { timelineSection }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas.ignoresSafeArea())
    }

    private var segmented: some View {
        HStack(spacing: 4) {
            ForEach(["People", "Timeline"].indices, id: \.self) { i in
                Button { withAnimation(.spring(duration: 0.35)) { mode = i } } label: {
                    Text(["People", "Timeline"][i]).font(.ui(15, .semibold))
                        .foregroundStyle(mode == i ? .white : Theme.mute)
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .background(Capsule().fill(mode == i ? AnyShapeStyle(Theme.cardGradient) : AnyShapeStyle(Color.clear)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(.white))
    }

    // MARK: People orbit

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusXL, style: .continuous).fill(Theme.heroGradient)
                ForEach(1..<4) { i in
                    Circle().stroke(.white.opacity(0.35), lineWidth: 1).frame(width: CGFloat(i) * 100, height: CGFloat(i) * 100)
                }
                Avatar(person: AvatarSpec(name: "Jeanne Morel", colors: [Color(hex: 0xFFD3A8), Theme.orange]), size: 84, ring: true)
                ForEach(Array(app.people.enumerated()), id: \.element.id) { i, p in
                    let angle = Double(i) / Double(app.people.count) * 2 * .pi - .pi / 2
                    let r: CGFloat = i % 2 == 0 ? 132 : 92
                    Button { withAnimation(.spring) { selected = p } } label: {
                        VStack(spacing: 4) {
                            Avatar(person: p.spec, size: selected == p ? 54 : 46, ring: true)
                            Text(p.name).font(.ui(11, .semibold)).foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: cos(angle) * r, y: sin(angle) * r)
                }
                Circle().fill(Theme.orange).frame(width: 10).offset(x: 120, y: 60)
                Circle().fill(Theme.orange).frame(width: 8).offset(x: -40, y: -140)
            }
            .frame(height: 340)
            .clipped()

            if let p = selected ?? app.people.first {
                personCard(p)
            }

            SectionHeader(title: "Family listening")
            VStack(spacing: 0) {
                ForEach(app.family) { m in
                    HStack(spacing: 12) {
                        Avatar(person: m.spec, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.name).font(.ui(15, .semibold)).foregroundStyle(Theme.ink)
                            Text(m.relation).font(.ui(13)).foregroundStyle(Theme.mute)
                        }
                        Spacer()
                        let asked = app.questions.filter { m.name.hasPrefix($0.author) }.count
                        if asked > 0 {
                            Text("\(asked) question\(asked > 1 ? "s" : "")").font(.ui(12, .semibold)).foregroundStyle(Theme.blue)
                                .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(Theme.blueWash))
                        }
                    }
                    .padding(.vertical, 10)
                }
                ShareLink(item: URL(string: "https://memoire.app/join/morel-family")!) {
                    Label("Invite someone", systemImage: "person.badge.plus")
                        .font(.ui(15, .semibold)).foregroundStyle(Theme.blue)
                        .frame(maxWidth: .infinity).padding(.top, 10)
                }
            }
            .card()
        }
    }

    private func personCard(_ p: PersonNode) -> some View {
        let stories = app.stories.filter { $0.people.contains(p.name) || $0.fullText.contains(p.name) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Avatar(person: p.spec, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(.display(18, .semibold)).foregroundStyle(Theme.ink)
                    Text("\(p.relation) · in \(stories.count) stor\(stories.count == 1 ? "y" : "ies")").font(.ui(13)).foregroundStyle(Theme.mute)
                }
                Spacer()
                Button { } label: { Image(systemName: "photo.badge.plus").font(.system(size: 18)).foregroundStyle(Theme.blue) }
                    .accessibilityLabel("Attach a photo of \(p.name)")
            }
            ForEach(stories) { s in
                Button { app.presentedStory = s } label: {
                    HStack {
                        Image(systemName: "play.circle.fill").foregroundStyle(Theme.blue)
                        Text(s.title).font(.ui(14, .medium)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(s.duration.clock).font(.ui(12)).foregroundStyle(Theme.mute)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .card()
        .id(p.id)
        .transition(.opacity)
    }

    // MARK: Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(app.timeline.enumerated()), id: \.element.id) { i, e in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(e.storyID != nil ? AnyShapeStyle(Theme.cardGradient) : AnyShapeStyle(Theme.blueMist))
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .padding(.top, 20)
                        if i < app.timeline.count - 1 {
                            Rectangle().fill(Theme.blueMist).frame(width: 2).frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 14)
                    Button {
                        if let id = e.storyID, let s = app.story(id) { app.presentedStory = s }
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(e.year)).font(.display(15, .bold)).foregroundStyle(Theme.blue)
                                Text(e.title).font(.ui(15, .semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                                Text(e.place).font(.ui(13)).foregroundStyle(Theme.mute)
                            }
                            Spacer()
                            if e.storyID != nil {
                                Image(systemName: "waveform").foregroundStyle(Theme.blue)
                                    .frame(width: 34, height: 34).background(Circle().fill(Theme.blueWash))
                            }
                        }
                        .card(padding: 14, radius: Theme.radiusM)
                    }
                    .buttonStyle(.plain)
                    .disabled(e.storyID == nil)
                    .padding(.bottom, 10)
                }
            }
        }
    }
}
