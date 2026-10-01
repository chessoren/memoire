import Foundation
import NaturalLanguage

/// "How did Grandma meet Grandpa?" → the real passages where she tells it.
///
/// Runs fully on-device (Apple NaturalLanguage sentence embeddings + lexical
/// boosts). It never generates an answer: it only returns timestamped
/// excerpts of what the storyteller actually said.
struct ArchiveHit: Identifiable, Hashable {
    var id: String { "\(story.id)-\(range.lowerBound)" }
    let story: Story
    let range: ClosedRange<Int>      // segment indices
    let score: Double

    var start: TimeInterval { story.segments[range.lowerBound].start }
    var end: TimeInterval { story.segments[range.upperBound].end }
    var text: String { story.segments[range].map(\.text).joined(separator: " ") }
}

enum ArchiveSearch {
    private static let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    /// Family vocabulary → names used in the archive.
    private static let aliases: [String: [String]] = [
        "grandpa": ["henri"], "grandfather": ["henri"], "papy": ["henri"], "husband": ["henri"],
        "meet": ["met", "dance", "waltz"], "met": ["dance", "waltz"], "married": ["married", "henri"],
        "mum": ["claire"], "mom": ["claire"], "born": ["born", "hospital"],
        "school": ["teacher", "class", "pupil", "children"], "teacher": ["school", "class"], "job": ["teacher", "school"],
        "car": ["2cv", "drive"], "holiday": ["sea", "collioure", "summer"], "vacation": ["sea", "collioure"],
        "cooking": ["kitchen", "brioche", "mouna", "dough"], "food": ["kitchen", "brioche", "peaches"],
        "childhood": ["seven", "mother", "kitchen", "oran"], "crazy": ["bicycle", "pyrenees"],
        "friend": ["simone"], "music": ["accordion", "marcel"],
    ]

    static func search(_ query: String, in stories: [Story], limit: Int = 3) -> [ArchiveHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let qTokens = tokens(q)
        var expanded = Set(qTokens)
        for t in qTokens { aliases[t]?.forEach { expanded.insert($0) } }
        let qVector = embedding?.vector(for: q)

        var hits: [ArchiveHit] = []
        for story in stories {
            let meta = tokens(story.title + " " + story.prompt + " " + story.theme + " " + story.people.joined(separator: " "))
            let metaOverlap = Double(expanded.intersection(meta).count)
            for i in story.segments.indices {
                let j = min(i + 1, story.segments.count - 1)
                let passage = story.segments[i...j].map(\.text).joined(separator: " ")
                var score = 0.0
                if let qVector, let pVector = embedding?.vector(for: passage) {
                    score += cosine(qVector, pVector) * 2.0
                }
                score += Double(expanded.intersection(tokens(passage)).count) * 0.35
                score += metaOverlap * 0.25
                hits.append(ArchiveHit(story: story, range: i...j, score: score))
            }
        }
        // Best passage per story, then best stories.
        var best: [String: ArchiveHit] = [:]
        for h in hits where (best[h.story.id]?.score ?? -.infinity) < h.score { best[h.story.id] = h }
        let ranked = best.values.sorted { $0.score > $1.score }
        guard let top = ranked.first else { return [] }
        return ranked.filter { $0.score >= top.score * 0.7 }.prefix(limit).map { widen($0) }
    }

    /// Give the listener a little context: one sentence before, one after.
    private static func widen(_ h: ArchiveHit) -> ArchiveHit {
        let lo = max(0, h.range.lowerBound - 1)
        let hi = min(h.story.segments.count - 1, h.range.upperBound + 1)
        return ArchiveHit(story: h.story, range: lo...hi, score: h.score)
    }

    private static let stop: Set<String> = ["the", "a", "an", "and", "or", "did", "does", "do", "how", "what", "when", "where", "who", "why", "her", "his", "she", "he", "was", "is", "to", "of", "in", "on", "for", "with", "about", "tell", "me", "grandma", "jeanne", "ever", "it", "that", "you", "your", "i", "my", "at"]

    static func tokens(_ s: String) -> Set<String> {
        let tagger = NLTokenizer(unit: .word)
        tagger.string = s
        var out = Set<String>()
        tagger.enumerateTokens(in: s.startIndex..<s.endIndex) { r, _ in
            let w = s[r].lowercased().folding(options: .diacriticInsensitive, locale: nil)
            if w.count > 1 && !stop.contains(w) {
                out.insert(w.hasSuffix("s") && w.count > 4 ? String(w.dropLast()) : w)
            }
            return true
        }
        return out
    }

    private static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        var dot = 0.0, na = 0.0, nb = 0.0
        for k in 0..<min(a.count, b.count) { dot += a[k] * b[k]; na += a[k] * a[k]; nb += b[k] * b[k] }
        return na > 0 && nb > 0 ? dot / (na.squareRoot() * nb.squareRoot()) : 0
    }
}
