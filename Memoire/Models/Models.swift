import SwiftUI

// MARK: - Archive content

struct Segment: Codable, Hashable {
    let text: String
    let start: TimeInterval
    let end: TimeInterval
}

struct Story: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let theme: String
    let year: Int
    let place: String
    let call: Int
    let date: String
    let prompt: String
    var askedBy: String?
    let people: [String]
    let highlight: Bool
    let segments: [Segment]
    let duration: TimeInterval
    /// Bundled resource name (m4a), or a recorded call file ("rec-….wav") in Documents.
    let audio: String
    var voice: String?
    /// Chapter prose written after the call (lightly edited, never adds facts).
    var chapter: String?

    var audioURL: URL? {
        if audio.hasPrefix("rec-") {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(audio)
        }
        return Bundle.main.url(forResource: audio, withExtension: "m4a")
    }

    var isLiveRecording: Bool { audio.hasPrefix("rec-") }

    var dateValue: Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: date) ?? .now
    }

    var excerpt: String { segments.first?.text ?? "" }
    var fullText: String { segments.map(\.text).joined(separator: " ") }

    var themeStyle: ThemeStyle { ThemeStyle.for(theme) }
}

struct ThemeStyle {
    let symbol: String
    let tint: Color
    let wash: Color
    static func `for`(_ theme: String) -> ThemeStyle {
        switch theme {
        case "Childhood": ThemeStyle(symbol: "sun.max.fill", tint: Theme.orange, wash: Theme.orangeWash)
        case "Love": ThemeStyle(symbol: "heart.fill", tint: Color(hex: 0xFF5A7A), wash: Color(hex: 0xFFE9EE))
        case "Work": ThemeStyle(symbol: "book.closed.fill", tint: Theme.purple, wash: Theme.purpleWash)
        case "Adventures": ThemeStyle(symbol: "car.fill", tint: Theme.blue, wash: Theme.blueWash)
        case "Family": ThemeStyle(symbol: "figure.2.and.child.holdinghands", tint: Theme.green, wash: Theme.greenWash)
        default: ThemeStyle(symbol: "waveform", tint: Theme.blue, wash: Theme.blueWash)
        }
    }
}

struct StorytellerInfo: Codable, Hashable {
    let name: String
    let callName: String
    let born: String
    let lives: String
    let career: String
}

struct ArchiveFile: Codable {
    let storyteller: StorytellerInfo
    let stories: [Story]
}

// MARK: - Family & questions

struct FamilyMember: Identifiable, Hashable, Codable {
    var id: String { name }
    let name: String
    let relation: String
    var colorA: UInt32 = 0x6CB8FF
    var colorB: UInt32 = 0x1A86FF
    var spec: AvatarSpec { AvatarSpec(name: name, colors: [Color(hex: colorA), Color(hex: colorB)]) }
}

struct FamilyQuestion: Identifiable, Hashable, Codable {
    var id = UUID()
    let text: String
    let author: String
    var votes: Int
    var voted = false
    var answeredStoryID: String? = nil
}

struct Reaction: Identifiable, Hashable, Codable {
    var id = UUID()
    let author: String
    let emoji: String
    let text: String
}

struct PersonNode: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let relation: String
    let mentions: Int
    let colors: [Color]
    var spec: AvatarSpec { AvatarSpec(name: name, colors: colors) }
}

struct LifeEvent: Identifiable, Hashable {
    var id: String { "\(year)-\(title)" }
    let year: Int
    let title: String
    let place: String
    var storyID: String? = nil
}

// MARK: - Onboarding profile

struct StorytellerProfile: Codable, Hashable {
    var firstName = "Jeanne"
    var relation = "My mother"
    var callName = "Mum"
    var birthYear = "1945"
    var birthPlace = "Oran"
    var places = "Oran, Toulouse, Ariège"
    var career = "Primary school teacher"
    var family = "Henri (late husband), Claire, Marc"
    var avoid: [String] = ["Algerian War", "Henri's illness"]
    var phone = "+33 6 12 34 56 78"
    var day = "Sunday"
    var hour = 15
    var biographer = "Louise"
    var announce = "I'll call her myself"
}
