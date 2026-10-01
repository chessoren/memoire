## Inspiration

This is the third of my Shipaton apps. Stick is about getting off the scroll. ilo is about what I want to do with the time I get back. Mémoire is about who I want to spend it with, while I still can.

My grandmother isn't here anymore. A while ago I asked my mom a simple question: how did her parents meet? She didn't know. They had never told her. It was one of those things that just wasn't talked about at home, and by the time anyone thought to ask properly, there was no one left to answer. It's a small question, and it's the one I regret most.

Then, going through old family photos, I found out something nobody had ever told me: my grandfather and my great-grandmother adored each other. Not in a polite, Sunday-lunch way. They were close, they laughed together, they had their own jokes. I learned it secondhand, years too late to hear either of them tell it.

That's the thing about family stories. Nobody is against keeping them, and almost nobody does. The kids don't dare, don't have time, and don't know what to ask: "we'll do it next Christmas." The grandparents find writing hard at 85, apps are a wall, and most of them think "my life isn't interesting anyway."

StoryWorth proved the demand: more than a million printed books from one emailed question a week. But a question in an inbox is still a blank page, and nobody asks the follow-up: *"wait, what was that soldier's name?"*

So the question for Mémoire was simple. What if someone called her every Sunday and actually listened? And what if, twenty years later, her great-grandchildren could still ask her how she met Grandpa, and hear her answer in her own voice?

## What it does

You gift Mémoire to a parent or grandparent. Every Sunday, Louise, a warm AI biographer, calls them. They install nothing and need no password. They just pick up. That night, the whole family gets the story in the app.

- **The gift, in four minutes.** The buyer writes a short portrait: where she lived, her work, her close family, the topics never to raise (a recent loss, a war, an illness), the call day and time, and the biographer's voice. Then the app gives them a script to tell her about it themselves. Nobody gets a call from an AI without being told first.
- **Louise, the biographer.** A real-time voice conversation using the oral-history method:
  - concrete before abstract: "describe the kitchen", not "tell me about your childhood";
  - a follow-up on every detail, and always the names of people and places;
  - a thread between calls: "last week you told me about your first school in Ariège."
- **She listens patiently.** Elderly people pause in the middle of a sentence, so Louise waits much longer than a normal assistant before she speaks. In my test call, Jeanne told her about her father's bakery in Oran, and Louise came back with: *"What was the name of the street where the bakery was located?"*
- **A chapter in her own words.** When the call ends, the app writes a chapter from the transcript. It removes the hesitations and keeps her expressions. It is forbidden to add a fact, a name or a date. People, places and years go into a living dossier that Louise reads before the next call.
- **Her real voice, in sync.** Every story plays with the transcript highlighted sentence by sentence, like lyrics. Tap any sentence to jump to that moment.
- **Ask, and she answers.** A grandson types "How did Grandma meet Grandpa?" Mémoire finds the passage where she tells it, plays exactly those seconds and highlights each sentence as she says it. If the answer isn't there yet, one tap sends the question to Louise for next Sunday. That's the feature I built for myself.
- **The family takes part.** Anyone can add a question for the next call, and the family votes on them. Louise picks the top question and says who asked it. Everyone can react to each story, and the app shows the people she talks about and a timeline of her life.

Two rules I cared about more than any feature:

1. **We never clone her voice.** Every answer in the archive is a real excerpt of a real call. This holds even after she's gone, even if the family asks.
2. **The storyteller is the real customer.** Louise says she's an AI, asks consent before recording, never raises the topics the family flagged, and is not a companion. She sends her back to her real family.

## How I built it

I built Mémoire in one afternoon on October 1, with Claude Code: about 4,100 lines of Swift in 21 files. The only dependency is RevenueCat.

- **The voice, with no SDK.** Louise runs on Gemini Live (`gemini-3.8-live-extended-thinking`) over a raw WebSocket:
  - the microphone is converted to 16 kHz audio and her voice comes back at 24 kHz;
  - echo cancellation stops the AI from hearing itself;
  - end-of-speech detection is set to its least sensitive level, with 1.6 seconds of silence before it's her turn.
- **Only her side is recorded.** The archive records the storyteller only, and pauses while Louise speaks. Each turn gets a timestamp, which is what makes the synced player and the archive search possible.
- **The model writes, the code keeps it honest.** The chapter is written by `gemini-3.8-flash` with high thinking and a JSON schema. The rule "no fact added" is written into the prompt.
- **Search that stays on the phone.** The archive uses Apple's NaturalLanguage sentence embeddings plus keyword matching, entirely on the iPhone. It returns timestamps, never generated text.
- **Every failure has a plan B.**
  - If Gemini Flash is overloaded, it falls back to Flash-Lite, then to 2.5 Flash.
  - If all of them fail, the recording is saved anyway and the chapter waits.
  - Without a RevenueCat key, the paywall switches to a demo mode.
- **Design.** I worked from a reference design system: blue gradients, floating white cards, a wide geometric display face. The storyteller's words are set in a serif, so they read like a book.

## How it makes money (RevenueCat)

The person who pays (an adult child) is not the person who uses it (the grandparent). The whole integration is built around that.

- **One entitlement, `family`.** It unlocks weekly calls, chapters and the archive for everyone.
- **One `default` offering with three packages**, all loaded from RevenueCat, so prices can be A/B tested without an update:
  - **The Gift**, the annual plan and the main offer: $79.99 a year in the Test Store. In production I want €119, sold as a gift.
  - **Monthly**, for families who want to try first: $9.99.
  - **Lifetime archive**, a one-time purchase that keeps every recording forever: $99.99.
- **The paywall comes last in onboarding.** By then the buyer has already written their mother's portrait, which is when the gift feels real. A "start with the free welcome call" option lets them hear it work first.
- **Listening stays free.** Every invited relative has grandparents of their own, so charging them to listen would break the growth loop.
- **Customer attributes.** `storyteller_relation`, `call_day` and `biographer_voice` are sent to RevenueCat, so revenue can be split by who the gift is for.
- **The rest of the integration:**
  - `customerInfoStream` drives access live;
  - restore purchases;
  - RevenueCatUI's Customer Center to manage the subscription;
  - a RevenueCat Test Store, so anyone who clones the repo can buy in the simulator without an Apple account.
- **The printed book is paid on the web.** Apple doesn't allow in-app purchases for physical goods.

## Challenges I ran into

- **My first Shipaton app blocked my third.** The simulator I used still had Stick's Screen Time shield running, and it blocked Mémoire at launch with "Not today." I had to create a fresh simulator just for Mémoire.
- **The disk hit 100%** in the middle of the build. I couldn't even run `df`. I freed 10 GB of Xcode caches and kept going.
- **Gemini was saturated.** `gemini-3.8-flash` kept answering "high demand", which is why the app falls back to lighter models and never loses a recording.
- **Ten requests a day.** The free tier allows only 10 text-to-speech requests per day per model, and I needed 38 sentences for the sample stories. So I made one request per story and asked the voice to pause between sentences. Then I found the pauses in the waveform and placed each sentence on the nearest real pause to where its length says it should start. That gives sentence-level sync from 6 requests.
- **A silent simulator.** The simulator's microphone gave Louise nothing to hear. I added a test hook that streams a recorded answer as if it were the mic, and only starts once Louise has finished her question.
- **"itis" and "aboutour".** Live transcription arrives in word-sized pieces that sometimes lose their space. Small, but it made Louise look sloppy.
- **A demo video with no sound.** Xcode 27 no longer ships a separate Simulator app, and the simulator's screen recording has no audio. In an app where the voice is the product, that was a problem. I wrote a small ScreenCaptureKit recorder for the system audio, a tool to merge it with the video, and an editor for the cuts and captions.

## Accomplishments that I'm proud of

My favourite moment is when Jeanne finishes her story about the bakery and Louise, without being told, asks for the name of the street. That's when it stops being a chatbot and starts being a biographer.

- A full loop that works: gift, live call, chapter, synced player, voice search.
- A red line written into the product, not just the pitch: no cloned voice, ever.
- An archive that answers with a real recording instead of generating text.
- An app that never loses a recording, even when the AI is down.

## What I learned

- **Ask now.** I didn't build Mémoire because the technology finally allows it. I built it because I waited too long to ask one question.
- **The voice is the product.** Text is easy to generate. A grandmother's laugh isn't.
- **Patience is a setting.** The difference between a good and a bad AI call for an 81-year-old is a few hundred milliseconds of silence.
- **The buyer isn't the user.** The paywall, the onboarding and the pricing all had to be designed for the person who gives the gift, while the experience is designed for the person who receives it.
- **Say what's real.** The sample stories in the demo are voiced by a TTS voice, and the app says so on each one. A product about trust can't fake its own demo.

## What's next for Mémoire

- **A real phone line** (Twilio or Telnyx, with a French number) so Louise calls a landline. Today she talks through the app's test call.
- **An EU backend** for families, sharing and the living dossier.
- **Five real grandparents first.** Success means at least 4 out of 5 say yes to a second call.
- **The printed book**, with a QR code to her voice in every chapter.
