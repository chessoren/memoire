# Mémoire

**Every Sunday, Mémoire calls your grandmother so she can tell the story of her life. Twenty years from now, your kids can still hear her tell it.**

Mémoire is a native iOS app for families. You give it to a parent or grandparent as a gift. Each week Louise, a warm AI biographer, phones them. She asks concrete questions, follows up on details and remembers what they said in earlier calls. That same evening the family gets the story in the app: the storyteller's **real voice**, a transcript that follows along as it plays, and a chapter for the book. Anyone in the family can add a question to next week's call. They can also search the archive in plain words, for example *"How did Grandma meet Grandpa?"*. The answer is the actual recording of her saying it.

Built for the **RevenueCat Shipaton 2026 · Next Gen Award**.

> The storyteller installs nothing and has no password. They just pick up the phone. The rest of the family uses the app.

---

## What's in this build

| Area | What works |
| --- | --- |
| **Onboarding** | Starts with a real memory you can play, before any marketing text. Then the gift setup, which takes under 4 minutes: who it's for, a short portrait, topics to avoid, call day and time, a choice of biographer voice, a script to announce the gift, the paywall, and family invites. |
| **Home** | The next call, family questions with voting, the newest story, reactions, and the plan Louise prepared for Sunday (written by Gemini 3.8 Flash with thinking set to high). |
| **Live call with Louise** | A real-time voice conversation using **Gemini Live** (`gemini-3.8-live-extended-thinking`) over a raw WebSocket, with no SDK. Turn detection is tuned for elderly speakers who pause mid-sentence (`END_SENSITIVITY_LOW`, 1.6 s silence). Echo cancellation is on. Only the storyteller's side of the call is recorded. |
| **Post-call pipeline** | Uses the transcript to write a chapter in the storyteller's own words with `gemini-3.8-flash` (thinking `HIGH`, JSON schema output). Hesitations are cleaned up but **no fact is added**. It also extracts people, places and the year, so the new story appears in the archive with its own audio. |
| **Stories** | The book in progress, organised by theme. A player shows the transcript in sync with the audio, like lyrics in a music app. Tap any sentence to jump to that moment. |
| **Ask** | Searches the voice archive on the device using Apple `NaturalLanguage` sentence embeddings plus keyword boosts. It returns timestamped excerpts of real recordings and plays the exact passage. It never generates an answer. |
| **Family** | An orbit of the people she mentions and a timeline of her life, both built from the calls. |
| **Account** | Subscription status with RevenueCat Customer Center, ordering the printed book through a web checkout (Apple doesn't allow in-app purchases for physical goods), the archive guardian, and our red line. |

## RevenueCat integration

Monetisation follows how the product is actually bought: **the person who pays (an adult child) is not the person who uses it (the grandparent)**.

- **One entitlement, `family`.** It unlocks weekly calls, chapters and the voice archive for everyone in the family. Listening stays free for anyone invited, because each listener is a future buyer for their own grandparents.
- **Offering `default`, three packages, all loaded from RevenueCat** (`Purchases.shared.offerings()`), so prices and plans can be A/B tested with RevenueCat Experiments without shipping an update:
  - **The Gift · 12 months.** The annual package and the main offer.
  - **Monthly.** For families who want to try first.
  - **Lifetime archive.** A one-time purchase that keeps every recording available forever.
- **The paywall comes last in onboarding.** By then the buyer has already written a portrait of their mother, which is when the gift feels real.
- **Free welcome call.** The buyer can skip the paywall, hear the first call, then upgrade from Home.
- **Customer attributes.** `storyteller_relation`, `call_day` and `biographer_voice` are sent to RevenueCat so revenue can be broken down by who the gift is for (mothers vs grandfathers, for example).
- **`customerInfoStream`** keeps the entitlement live across the app.
- **RevenueCatUI `CustomerCenterView`** lets the user manage the subscription.
- **Restore purchases.**
- **Physical book.** Paid through a web checkout and not through IAP, which follows Apple's rules.

The repo ships configured with a **RevenueCat Test Store** key, so the whole purchase flow runs on the simulator with no App Store Connect account.

## Architecture

```
Memoire/
  App/            AppState (@Observable), root, tab bar, mini player
  DesignSystem/   Theme tokens, components (cards, chips, waveform, phone mockup…)
  Models/         Story, Segment (timestamped), family, profile
  Services/
    GeminiLive.swift    WebSocket client + AVAudioEngine (16 kHz in / 24 kHz out, AEC, gated recording)
    GeminiText.swift    post-call chapter + call plan (gemini-3.8-flash, thinking HIGH, JSON schema)
    Biographer.swift    Louise's system prompt: oral-history method, sensitive topics, ethics
    ArchiveSearch.swift on-device semantic search over timestamped segments
    Purchases.swift     RevenueCat offerings, purchase, restore, attributes
    AudioPlayer.swift   one shared player with segment-level sync
  Features/       Onboarding, Home, Call, Stories, Ask, Family, Profile, Paywall
scripts/
  stories.source.json   demo storyteller content
  generate_audio.py     per-sentence TTS → m4a + exact segment timings
```

SwiftUI and the Observation framework, iOS 26+, and **no third-party dependency except RevenueCat**.

## Run it

1. Open `Memoire.xcodeproj` in Xcode 27 and run the `Memoire` scheme on an iOS 26+ simulator.
2. Purchases work right away through the RevenueCat Test Store.
3. Live calls with Louise and post-call chapters need a Gemini API key. Create `Memoire/Config/Secrets.plist` (it is git-ignored):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>GEMINI_API_KEY</key><string>YOUR_KEY</string></dict></plist>
```

Or set `GEMINI_API_KEY` as an environment variable in the scheme. In production the key lives server-side and the app uses Gemini ephemeral tokens.

Useful launch arguments for demos: `-hasOnboarded YES`, `-tab stories|ask|family|profile`, `-paywall YES`, `-story deux-cv`.

## Ethics: the red line

1. **We never synthesise a storyteller's voice.** Every answer in the archive is a real excerpt of a real call. We don't clone voices, not even after someone has died.
2. **Louise always says she is an AI** and asks for consent to record during the first call.
3. **The storyteller stays in control.** They can say "keep that out of the book" or "stop the calls", and it happens.
4. **No emotional manipulation.** Louise is not a companion. She encourages real family ties.
5. **Topics the buyer marks as sensitive are never raised.**

> **Demo disclosure.** The six sample stories in this repo were written for the demo and voiced with TTS (`scripts/generate_audio.py`). They are labelled in the app. A real family's archive only ever contains real recordings.

## Why us, when "AI calls grandma" already exists

Tell Mel, LifeLoom, StoriesFrom and Storii prove the demand. They are US websites built around the book. Mémoire is different on three points:

- A **native iOS app where the whole family takes part every week**: questions, votes, reactions, and searching the voice archive.
- It is **made for Europe**: EU hosting, GDPR, prices in euros, local printing.
- The **voice is treated as the product**, not just the text.

## License

MIT. See [LICENSE](LICENSE).
