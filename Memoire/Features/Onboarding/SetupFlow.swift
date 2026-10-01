import AVFoundation
import SwiftUI

/// The buyer's portrait of the storyteller — the biographer's initial brief.
/// Every field is optional and editable later. Under four minutes.
struct SetupFlow: View {
    @Environment(AppState.self) private var app
    @State private var step = 0
    let onBack: () -> Void
    let onDone: () -> Void

    private let titles = ["Who is it for?", "Their portrait", "Topics to avoid", "When should we call?", "How will they hear about it?"]
    private let subtitles = [
        "Nobody gets a call from an AI without being told first. Start with who they are to you.",
        "Louise uses this to ask concrete questions from the very first call. Skip anything you like.",
        "Louise will never bring these up herself. If they choose to talk about it, she listens gently.",
        "Pick their ritual. They can change it themselves during a call: “call me Saturday instead”.",
        "The first call is a short welcome: Louise introduces herself as an AI and asks their consent to record.",
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(titles[step]).font(.display(26, .semibold)).foregroundStyle(Theme.ink)
                        Text(subtitles[step]).font(.ui(15)).foregroundStyle(Theme.inkSoft).lineSpacing(2)
                    }
                    Group {
                        switch step {
                        case 0: WhoStep()
                        case 1: PortraitStep()
                        case 2: AvoidStep()
                        case 3: SlotStep()
                        default: AnnounceStep()
                        }
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 120)
                .id(step)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            Button(step == titles.count - 1 ? "Continue" : "Next") {
                if step < titles.count - 1 { withAnimation(.spring(duration: 0.4)) { step += 1 } } else { onDone() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 8)
            .background(LinearGradient(colors: [Theme.canvas.opacity(0), Theme.canvas], startPoint: .top, endPoint: .center).ignoresSafeArea())
        }
        .background(Theme.canvas.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 14) {
            CircleIconButton(systemName: "chevron.left", size: 42) {
                if step == 0 { onBack() } else { withAnimation(.spring(duration: 0.4)) { step -= 1 } }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.blueMist)
                    Capsule().fill(Theme.cardGradient).frame(width: g.size.width * Double(step + 1) / Double(titles.count))
                }
            }
            .frame(height: 8)
            .animation(.spring, value: step)
            Text("\(step + 1)/\(titles.count)").font(.ui(14, .semibold)).foregroundStyle(Theme.mute).monospacedDigit()
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 10)
    }
}

// MARK: - Fields

struct FieldCard: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ui(13, .medium)).foregroundStyle(Theme.mute)
            TextField(placeholder, text: $text)
                .font(.ui(17, .medium))
                .foregroundStyle(Theme.ink)
                .keyboardType(keyboard)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.hairline))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing
            row = max(row, size.height)
        }
        return CGSize(width: width, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX { x = bounds.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}

// MARK: - Steps

struct WhoStep: View {
    @Environment(AppState.self) private var app
    let relations = ["My mother", "My father", "My grandmother", "My grandfather", "Another loved one"]
    var body: some View {
        @Bindable var app = app
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Avatar(person: AvatarSpec(name: app.profile.firstName.isEmpty ? "?" : app.profile.firstName,
                                          colors: [Color(hex: 0xFFD3A8), Theme.orange]), size: 64, ring: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add a photo").font(.ui(15, .semibold)).foregroundStyle(Theme.blue)
                    Text("Optional — shown on the family's home screen").font(.ui(13)).foregroundStyle(Theme.mute)
                }
            }
            .card()
            FieldCard(label: "Their first name", text: $app.profile.firstName, placeholder: "Jeanne")
            Text("They are…").font(.ui(13, .medium)).foregroundStyle(Theme.mute).padding(.top, 4)
            FlowLayout {
                ForEach(relations, id: \.self) { r in
                    Button { app.profile.relation = r } label: { Chip(text: r, selected: app.profile.relation == r) }
                        .buttonStyle(.plain)
                }
            }
            FieldCard(label: "What does the family call them?", text: $app.profile.callName, placeholder: "Mum, Grandma, Mamie…")
        }
    }
}

struct PortraitStep: View {
    @Environment(AppState.self) private var app
    var body: some View {
        @Bindable var app = app
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                FieldCard(label: "Born in", text: $app.profile.birthYear, placeholder: "1945", keyboard: .numberPad)
                FieldCard(label: "Born at", text: $app.profile.birthPlace, placeholder: "Oran")
            }
            FieldCard(label: "Places they lived", text: $app.profile.places, placeholder: "Oran, Toulouse…")
            FieldCard(label: "Work", text: $app.profile.career, placeholder: "Teacher")
            FieldCard(label: "Close family", text: $app.profile.family, placeholder: "Husband, children…")
        }
    }
}

struct AvoidStep: View {
    @Environment(AppState.self) private var app
    @State private var custom = ""
    let suggestions = ["A recent loss", "Illness", "Family conflict", "Divorce", "Algerian War", "Henri's illness", "Money"]
    var body: some View {
        @Bindable var app = app
        VStack(alignment: .leading, spacing: 16) {
            FlowLayout {
                ForEach(Array(Set(suggestions + app.profile.avoid)).sorted(), id: \.self) { s in
                    let on = app.profile.avoid.contains(s)
                    Button {
                        if on { app.profile.avoid.removeAll { $0 == s } } else { app.profile.avoid.append(s) }
                    } label: { Chip(text: s, selected: on, systemName: on ? "hand.raised.fill" : "plus") }
                        .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("Something else…", text: $custom).font(.ui(16))
                Button("Add") {
                    let t = custom.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { app.profile.avoid.append(t); custom = "" }
                }
                .font(.ui(15, .semibold))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Theme.radiusM).fill(.white))
            HStack(alignment: .top, spacing: 12) {
                IconBadge(systemName: "lock.shield.fill", tint: Theme.blue, wash: Theme.blueWash, size: 36)
                Text("Only you and the biographer see this list. It is never read aloud and never appears in the book.")
                    .font(.ui(14)).foregroundStyle(Theme.inkSoft)
            }
            .card()
        }
    }
}

struct SlotStep: View {
    @Environment(AppState.self) private var app
    @State private var synth = AVSpeechSynthesizer()
    let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    var body: some View {
        @Bindable var app = app
        VStack(alignment: .leading, spacing: 16) {
            FieldCard(label: "\(app.profile.firstName)'s phone (mobile or landline)", text: $app.profile.phone, keyboard: .phonePad)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { d in
                        Button { app.profile.day = d } label: { Chip(text: String(d.prefix(3)), selected: app.profile.day == d) }
                            .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time").font(.ui(13, .medium)).foregroundStyle(Theme.mute)
                    Text(String(format: "%d:00 %@", app.profile.hour > 12 ? app.profile.hour - 12 : app.profile.hour, app.profile.hour >= 12 ? "PM" : "AM"))
                        .font(.display(22, .semibold)).foregroundStyle(Theme.ink)
                }
                Spacer()
                Stepper("", value: $app.profile.hour, in: 9...20).labelsHidden()
            }
            .card()

            Text("Biographer's voice").font(.ui(13, .medium)).foregroundStyle(Theme.mute).padding(.top, 4)
            HStack(spacing: 12) {
                voiceCard("Louise", "Warm, gentle", female: true)
                voiceCard("Paul", "Calm, deep", female: false)
            }
            Toggle(isOn: .constant(false)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hard of hearing").font(.ui(16, .medium))
                    Text("Slower, lower voice; repeats when asked “pardon?”").font(.ui(13)).foregroundStyle(Theme.mute)
                }
            }
            .card()
        }
    }

    func voiceCard(_ name: String, _ desc: String, female: Bool) -> some View {
        let selected = app.profile.biographer == name
        return Button {
            app.profile.biographer = name
            let u = AVSpeechUtterance(string: "Hello \(app.profile.firstName), it's \(name), calling on behalf of Claire. How was your week?")
            u.voice = AVSpeechSynthesisVoice(language: female ? "en-GB" : "en-US")
            u.rate = 0.45
            synth.stopSpeaking(at: .immediate)
            synth.speak(u)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    IconBadge(systemName: "waveform", tint: selected ? .white : Theme.blue, wash: selected ? .white.opacity(0.2) : Theme.blueWash, size: 36)
                    Spacer()
                    Image(systemName: "play.circle.fill").font(.system(size: 24)).foregroundStyle(selected ? .white : Theme.blue)
                }
                Text(name).font(.display(18, .semibold))
                Text(desc).font(.ui(13)).opacity(0.8)
            }
            .foregroundStyle(selected ? .white : Theme.ink)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .fill(selected ? AnyShapeStyle(Theme.cardGradient) : AnyShapeStyle(Color.white)))
        }
        .buttonStyle(.plain)
    }
}

struct AnnounceStep: View {
    @Environment(AppState.self) private var app
    var body: some View {
        @Bindable var app = app
        VStack(alignment: .leading, spacing: 14) {
            option("I'll call her myself", "Recommended. Here's a script you can use.", "phone.fill", Theme.green, Theme.greenWash)
            if app.profile.announce == "I'll call her myself" {
                Text("“\(app.profile.callName), I've got you a present. Every \(app.profile.day), a lady called \(app.profile.biographer) will phone you. She's an AI, a sort of very polite robot, and she'd love to hear about your life — the kitchen in \(app.profile.birthPlace), your pupils, Dad. You just talk. If you don't like it, you just say stop. And we'll all get to hear your stories.”")
                    .font(.story(16).italic())
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(4)
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: Theme.radiusL).fill(Theme.blueWash))
            }
            option("Send a postcard", "We mail a printed card with your handwritten-style note.", "envelope.fill", Theme.orange, Theme.orangeWash)
        }
    }

    func option(_ title: String, _ sub: String, _ icon: String, _ tint: Color, _ wash: Color) -> some View {
        let selected = app.profile.announce == title
        return Button { withAnimation(.spring) { app.profile.announce = title } } label: {
            HStack(spacing: 14) {
                IconBadge(systemName: icon, tint: tint, wash: wash, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.ui(16, .semibold)).foregroundStyle(Theme.ink)
                    Text(sub).font(.ui(13)).foregroundStyle(Theme.mute)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22)).foregroundStyle(selected ? Theme.blue : Theme.hairline)
            }
            .card()
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusL).stroke(selected ? Theme.blue : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Invite

struct InviteFamilyView: View {
    @Environment(AppState.self) private var app
    let onDone: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Theme.heroGradient.ignoresSafeArea()
                FamilyOrbitIllustration().padding(.top, 0).scaleEffect(0.85)
            }
            .frame(height: 380)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 36, bottomTrailingRadius: 36, style: .continuous))
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 14) {
                Text("Invite the family").font(.display(25, .semibold)).foregroundStyle(Theme.ink)
                Text("Listening is free for everyone you invite. They get Sunday's story, react, and add their own questions.")
                    .font(.ui(16)).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
                ShareLink(item: URL(string: "https://memoire.app/join/morel-family")!,
                          message: Text("Every Sunday, Louise calls \(app.callName) to record her life story. Join the family on Mémoire:")) {
                    Label("Share invite link", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
                Button("Continue to the app", action: onDone)
                    .font(.ui(16, .semibold))
                    .foregroundStyle(Theme.blue)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            Spacer()
        }
        .background(Theme.canvas.ignoresSafeArea())
    }
}
