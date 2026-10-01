import SwiftUI

@MainActor
@Observable
final class AppState {
    // Persisted flags
    var hasOnboarded: Bool { didSet { UserDefaults.standard.set(hasOnboarded, forKey: "hasOnboarded") } }
    var profile: StorytellerProfile { didSet { save(profile, "profile") } }
    var questions: [FamilyQuestion] { didSet { save(questions, "questions") } }
    var recordedStories: [Story] { didSet { save(recordedStories, "recordedStories") } }
    var reactions: [String: [Reaction]] { didSet { save(reactions, "reactions") } }

    // Content
    let storyteller: StorytellerInfo
    private let bundledStories: [Story]

    // UI
    var selectedTab: Tab = .home
    var toast: String?
    var presentedStory: Story?
    var showPaywall = false
    var showLiveCall = false

    let me = FamilyMember(name: "Claire Morel", relation: "Daughter", colorA: 0x7FC4FF, colorB: 0x1A86FF)

    let family: [FamilyMember] = [
        FamilyMember(name: "Claire Morel", relation: "Daughter", colorA: 0x7FC4FF, colorB: 0x1A86FF),
        FamilyMember(name: "Marc Morel", relation: "Son", colorA: 0xFFC38B, colorB: 0xFF8A3D),
        FamilyMember(name: "Lucas Morel", relation: "Grandson", colorA: 0xB9A6FF, colorB: 0x8B6CFF),
        FamilyMember(name: "Emma Morel", relation: "Granddaughter", colorA: 0x8BE3B2, colorB: 0x2FC46B),
        FamilyMember(name: "Sophie Morel", relation: "Daughter-in-law", colorA: 0xFFB1C1, colorB: 0xFF5A7A),
    ]

    enum Tab: Hashable { case home, stories, ask, family, profile }

    init() {
        let defaults = UserDefaults.standard
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")
        profile = Self.load("profile") ?? StorytellerProfile()
        questions = Self.load("questions") ?? Self.seedQuestions
        recordedStories = Self.load("recordedStories") ?? []
        reactions = Self.load("reactions") ?? Self.seedReactions

        let url = Bundle.main.url(forResource: "stories", withExtension: "json")!
        let archive = try! JSONDecoder().decode(ArchiveFile.self, from: Data(contentsOf: url))
        storyteller = archive.storyteller
        bundledStories = archive.stories

        // Launch arguments for demo recording: -tab stories|ask|family|profile, -story <id>
        switch defaults.string(forKey: "tab") {
        case "stories": selectedTab = .stories
        case "ask": selectedTab = .ask
        case "family": selectedTab = .family
        case "profile": selectedTab = .profile
        default: break
        }
        showPaywall = defaults.bool(forKey: "paywall")
        if let id = defaults.string(forKey: "story") { presentedStory = stories.first { $0.id == id } }
    }

    // MARK: Derived

    var stories: [Story] {
        (recordedStories + bundledStories).sorted { ($0.call, $0.dateValue) > ($1.call, $1.dateValue) }
    }

    var latestStory: Story { stories.first! }

    var callName: String { profile.callName.isEmpty ? "Grandma" : profile.callName }
    var storytellerFirstName: String { profile.firstName.isEmpty ? "Jeanne" : profile.firstName }

    var totalListeningTime: TimeInterval { stories.reduce(0) { $0 + $1.duration } }

    var nextCallDate: Date {
        let weekday = ["Sunday": 1, "Monday": 2, "Tuesday": 3, "Wednesday": 4, "Thursday": 5, "Friday": 6, "Saturday": 7][profile.day] ?? 1
        var c = DateComponents(); c.weekday = weekday; c.hour = profile.hour; c.minute = 0
        return Calendar.current.nextDate(after: .now, matching: c, matchingPolicy: .nextTime) ?? .now
    }

    var themes: [String] {
        let order = ["Childhood", "Love", "Work", "Family", "Adventures"]
        let present = Set(stories.map(\.theme))
        return order.filter(present.contains) + present.subtracting(order).sorted()
    }

    func story(_ id: String) -> Story? { stories.first { $0.id == id } }

    // MARK: Actions

    func addQuestion(_ text: String) {
        let q = FamilyQuestion(text: text, author: "Claire", votes: 1, voted: true)
        questions.insert(q, at: 0)
        flash("Question added to Sunday's call")
    }

    func toggleVote(_ q: FamilyQuestion) {
        guard let i = questions.firstIndex(of: q) else { return }
        questions[i].voted.toggle()
        questions[i].votes += questions[i].voted ? 1 : -1
    }

    var nextQuestion: FamilyQuestion? {
        questions.filter { $0.answeredStoryID == nil }.max { $0.votes < $1.votes }
    }

    func react(to story: Story, emoji: String) {
        var list = reactions[story.id] ?? []
        list.removeAll { $0.author == "Claire" }
        list.append(Reaction(author: "Claire", emoji: emoji, text: ""))
        reactions[story.id] = list
    }

    func addRecordedStory(_ story: Story) {
        recordedStories.insert(story, at: 0)
    }

    func flash(_ message: String) {
        withAnimation(.spring) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            withAnimation(.spring) { if toast == message { toast = nil } }
        }
    }

    func resetDemo() {
        recordedStories = []
        questions = Self.seedQuestions
        reactions = Self.seedReactions
        profile = StorytellerProfile()
        hasOnboarded = false
    }

    // MARK: People & timeline (built from the archive)

    var people: [PersonNode] {
        [
            PersonNode(name: "Henri", relation: "Husband · 1941–2019", mentions: mentions("Henri"), colors: [Color(hex: 0x7FC4FF), Color(hex: 0x1A86FF)]),
            PersonNode(name: "Claire", relation: "Daughter", mentions: mentions("Claire"), colors: [Color(hex: 0xFFC38B), Color(hex: 0xFF8A3D)]),
            PersonNode(name: "Simone", relation: "Best friend, Oran", mentions: mentions("Simone"), colors: [Color(hex: 0xB9A6FF), Color(hex: 0x8B6CFF)]),
            PersonNode(name: "Marcel", relation: "Accordionist", mentions: mentions("Marcel"), colors: [Color(hex: 0x8BE3B2), Color(hex: 0x2FC46B)]),
            PersonNode(name: "Pierrot", relation: "First pupil", mentions: mentions("Pierrot"), colors: [Color(hex: 0xFFB1C1), Color(hex: 0xFF5A7A)]),
            PersonNode(name: "Lucas", relation: "Grandson", mentions: mentions("Lucas"), colors: [Color(hex: 0x9AD7FF), Color(hex: 0x3D9DFF)]),
        ]
    }

    private func mentions(_ name: String) -> Int {
        stories.filter { $0.people.contains(name) || $0.fullText.contains(name) }.count
    }

    var timeline: [LifeEvent] {
        var events: [LifeEvent] = [
            LifeEvent(year: 1945, title: "Born in Oran", place: "Algeria"),
            LifeEvent(year: 1963, title: "Moves to Toulouse", place: "France"),
            LifeEvent(year: 1967, title: "Marries Henri", place: "Toulouse"),
            LifeEvent(year: 1978, title: "Marc is born", place: "Toulouse"),
            LifeEvent(year: 2005, title: "Retires after 39 years of teaching", place: "Toulouse"),
        ]
        for s in stories where s.year > 0 {
            events.append(LifeEvent(year: s.year, title: s.title, place: s.place, storyID: s.id))
        }
        return events.sorted { $0.year < $1.year }
    }

    // MARK: Seeds

    static let seedQuestions: [FamilyQuestion] = [
        FamilyQuestion(text: "What was the farm in Tlemcen like? Did you ever go back?", author: "Marc", votes: 4),
        FamilyQuestion(text: "What did you and Grandpa do on your first date?", author: "Emma", votes: 3),
        FamilyQuestion(text: "Which pupil made you laugh the most?", author: "Sophie", votes: 1),
        FamilyQuestion(text: "Did Grandpa ever do something crazy when he was young?", author: "Lucas", votes: 6, answeredStoryID: "bicycle"),
    ]

    static let seedReactions: [String: [Reaction]] = [
        "deux-cv": [
            Reaction(author: "Marc", emoji: "😂", text: "The tractor!!"),
            Reaction(author: "Lucas", emoji: "❤️", text: ""),
            Reaction(author: "Emma", emoji: "🥹", text: "I want to go to Collioure with her"),
        ],
        "bicycle": [
            Reaction(author: "Lucas", emoji: "🤯", text: "Grandpa was a legend"),
        ],
        "dance": [
            Reaction(author: "Sophie", emoji: "🥹", text: ""),
            Reaction(author: "Marc", emoji: "❤️", text: "Never heard this one"),
        ],
    ]

    // MARK: Persistence

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
