import Foundation

/// Post-call pipeline on gemini-3.8-flash with thinkingLevel HIGH:
/// segment the conversation, title it, extract people and places, and write
/// a chapter in the storyteller's own words. Strict rule: clean repetitions and
/// hesitations, never add a fact.
enum GeminiText {
    struct ChapterResult: Decodable {
        let title: String
        let theme: String
        let year: Int
        let place: String
        let people: [String]
        let chapter: String
        let highlight: String
        let notification: String
    }

    enum Failure: LocalizedError {
        case noKey, badResponse(String)
        var errorDescription: String? {
            switch self {
            case .noKey: "Missing Gemini API key."
            case .badResponse(let s): s
            }
        }
    }

    static func writeChapter(transcript: String, storyteller: String) async throws -> ChapterResult {
        let system = """
        You are the editor of Mémoire, a family memoir service. You receive the transcript of a phone call between Louise (an AI biographer) and \(storyteller).
        Produce a chapter for the family book, in the first person, in \(storyteller)'s own voice and words.
        Rules: keep their wording and expressions; remove hesitations, repetitions and the biographer's questions; NEVER add a fact, a name, a date or an emotion that is not in the transcript.
        If something is unknown, use your best grounded guess from the transcript for year/place, otherwise year 0 and place "".
        theme must be one of: Childhood, Love, Work, Family, Adventures, Places, Traditions.
        highlight: the single most moving sentence they actually said, verbatim.
        notification: a push notification for the family, e.g. "Grandma just told the story of her first dance" (max 70 characters).
        """
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "theme": ["type": "string"],
                "year": ["type": "integer"],
                "place": ["type": "string"],
                "people": ["type": "array", "items": ["type": "string"]],
                "chapter": ["type": "string"],
                "highlight": ["type": "string"],
                "notification": ["type": "string"],
            ],
            "required": ["title", "theme", "year", "place", "people", "chapter", "highlight", "notification"],
        ]
        let text = try await generate(system: system, prompt: "Transcript:\n\n\(transcript)", schema: schema)
        return try JSONDecoder().decode(ChapterResult.self, from: Data(text.utf8))
    }

    /// Louise's plan for the next call, prepared from the living dossier.
    static func callPlan(dossier: String) async throws -> String {
        let system = """
        You prepare the plan for Louise, an AI biographer, before her weekly call with an elderly storyteller.
        Output plain text, 5 short lines, no markdown: 1) Warm opening line 2) Thread from a previous story 3) Today's theme and the concrete opening question 4) Two follow-up angles 5) The family question and who asked it.
        Avoid every sensitive topic listed.
        """
        return try await generate(system: system, prompt: dossier, schema: nil)
    }

    private static func generate(system: String, prompt: String, schema: [String: Any]?) async throws -> String {
        guard let key = Config.geminiAPIKey else { throw Failure.noKey }
        var config: [String: Any] = ["thinkingConfig": ["thinkingLevel": "HIGH"]]
        if let schema {
            config["responseMimeType"] = "application/json"
            config["responseJsonSchema"] = schema
        }
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": config,
        ]
        var req = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(Config.textModel):generateContent")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.badResponse("Unreadable response")
        }
        if (response as? HTTPURLResponse)?.statusCode != 200 {
            let msg = ((json["error"] as? [String: Any])?["message"] as? String) ?? "HTTP error"
            throw Failure.badResponse(msg)
        }
        let parts = (((json["candidates"] as? [[String: Any]])?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]]) ?? []
        let text = parts.filter { $0["thought"] as? Bool != true }.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw Failure.badResponse("Empty response") }
        return text
    }
}
