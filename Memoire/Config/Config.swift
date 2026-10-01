import Foundation

enum Config {
    /// RevenueCat public SDK key (Test Store key for the hackathon build — safe to ship in the client).
    static let revenueCatAPIKey = "test_ibcbhzDivraEEEiNvwUCxPhamgo"
    static let entitlementID = "family"

    /// Gemini models: Live for the voice call, Flash (high thinking) for the call brief and the chapter.
    static let liveModel = "gemini-3.8-live-extended-thinking"
    static let liveThinkingLevel = "LOW"      // keeps replies under ~1 s on a phone line
    static let textModel = "gemini-3.8-flash" // runs with thinkingLevel HIGH
    static let biographerVoice = "Sulafat"    // "Warm"

    /// Gemini API key is never committed. Provide it via Memoire/Config/Secrets.plist (git-ignored,
    /// key `GEMINI_API_KEY`) or the `GEMINI_API_KEY` scheme environment variable.
    static var geminiAPIKey: String? {
        if let env = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !env.isEmpty { return env }
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url),
           let key = dict["GEMINI_API_KEY"] as? String, !key.isEmpty { return key }
        return nil
    }

    static var isRevenueCatConfigured: Bool { !revenueCatAPIKey.contains("REPLACE") }

    /// Printed book is a physical good: Apple forbids IAP for it, so it goes through a web checkout.
    static let bookCheckoutURL = URL(string: "https://memoire.app/book")!
}
