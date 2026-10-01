import AVFoundation
import Foundation

// Real-time voice conversation with the AI biographer over the Gemini Live API
// (raw WebSocket, no SDK). Mic → 16 kHz PCM16 → Gemini; Gemini → 24 kHz PCM16 → speaker.
// The storyteller's own voice is recorded locally, gated while the biographer
// speaks, so the archive keeps *their* words with timestamps.

// MARK: - Audio I/O (audio thread)

final class LiveAudioIO: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let playFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24000, channels: 1, interleaved: false)!
    private let sendFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
    private var converter: AVAudioConverter?
    private var recordFile: AVAudioFile?
    private let lock = NSLock()
    private var pendingBuffers = 0
    private var _recordedFrames: Int64 = 0

    var onChunk: ((Data, Float) -> Void)?
    var muted = false
    var onOutputLevel: ((Float) -> Void)?

    var isModelSpeaking: Bool { lock.withLock { pendingBuffers > 0 } }
    var recordedSeconds: Double { lock.withLock { Double(_recordedFrames) / 16000 } }

    func start(recordingTo url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        let input = engine.inputNode
        #if !targetEnvironment(simulator)
        try? input.setVoiceProcessingEnabled(true)   // echo cancellation: the biographer must not hear itself
        #endif
        let inFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inFormat, to: sendFormat)
        recordFile = try AVAudioFile(forWriting: url, settings: sendFormat.settings,
                                     commonFormat: .pcmFormatInt16, interleaved: true)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: playFormat)
        input.installTap(onBus: 0, bufferSize: 2048, format: inFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        engine.prepare()
        try engine.start()
        player.play()
        if let feed = UserDefaults.standard.string(forKey: "feedAudio") { startFeed(path: feed) }
    }

    /// Test hook (`-feedAudio /path/file.wav`): streams a recording as if it were the microphone,
    /// so the full call → chapter pipeline can be exercised without a human on the simulator.
    private var feedTimer: DispatchSourceTimer?
    private func startFeed(path: String) {
        guard let file = try? AVAudioFile(forReading: URL(fileURLWithPath: path)),
              let conv = AVAudioConverter(from: file.processingFormat, to: sendFormat) else { return }
        let total = AVAudioFrameCount(file.length)
        guard let src = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: total),
              (try? file.read(into: src)) != nil else { return }
        let outCap = AVAudioFrameCount(Double(total) * sendFormat.sampleRate / file.processingFormat.sampleRate) + 1024
        guard let all = AVAudioPCMBuffer(pcmFormat: sendFormat, frameCapacity: outCap) else { return }
        var fed = false
        conv.convert(to: all, error: nil) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true; status.pointee = .haveData; return src
        }
        var offset = 0
        let chunk = 1600 // 100 ms
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + 4, repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self, let samples = all.int16ChannelData?[0] else { return }
            let n = min(chunk, Int(all.frameLength) - offset)
            if n <= 0 {
                // keep streaming silence so the server VAD can close the turn
                var silence = [Int16](repeating: 0, count: chunk)
                self.onChunk?(Data(bytes: &silence, count: chunk * 2), 0)
                return
            }
            let data = Data(bytes: samples + offset, count: n * 2)
            if let rec = self.recordFile, let buf = AVAudioPCMBuffer(pcmFormat: self.sendFormat, frameCapacity: AVAudioFrameCount(n)) {
                buf.frameLength = AVAudioFrameCount(n)
                memcpy(buf.int16ChannelData![0], samples + offset, n * 2)
                try? rec.write(from: buf)
                self.lock.withLock { self._recordedFrames += Int64(n) }
            }
            offset += n
            self.onChunk?(data, 0.5)
        }
        timer.resume()
        feedTimer = timer
    }

    func stop() {
        feedTimer?.cancel()
        feedTimer = nil
        engine.inputNode.removeTap(onBus: 0)
        player.stop()
        engine.stop()
        recordFile = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let converter, feedTimer == nil else { return }
        let ratio = sendFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: sendFormat, frameCapacity: capacity) else { return }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, out.frameLength > 0, let samples = out.int16ChannelData?[0] else { return }
        let count = Int(out.frameLength)
        var sum: Float = 0
        for i in 0..<count { let v = Float(samples[i]) / 32768; sum += v * v }
        let rms = min(1, sqrt(sum / Float(count)) * 6)
        if muted { memset(samples, 0, count * 2) }
        onChunk?(Data(bytes: samples, count: count * 2), muted ? 0 : rms)

        // Keep only the storyteller's side in the archive recording.
        if !isModelSpeaking, let recordFile {
            try? recordFile.write(from: out)
            lock.withLock { _recordedFrames += Int64(count) }
        }
    }

    func play(pcm16 data: Data) {
        let frames = data.count / 2
        guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: playFormat, frameCapacity: AVAudioFrameCount(frames)) else { return }
        buf.frameLength = AVAudioFrameCount(frames)
        let dst = buf.floatChannelData![0]
        var peak: Float = 0
        data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: Int16.self)
            for i in 0..<frames {
                let v = Float(Int16(littleEndian: src[i])) / 32768
                dst[i] = v
                peak = max(peak, abs(v))
            }
        }
        onOutputLevel?(min(1, peak * 1.6))
        lock.withLock { pendingBuffers += 1 }
        player.scheduleBuffer(buf) { [weak self] in
            guard let self else { return }
            let left = self.lock.withLock { () -> Int in self.pendingBuffers = max(0, self.pendingBuffers - 1); return self.pendingBuffers }
            if left == 0 { self.onOutputLevel?(0) }
        }
    }

    func flushPlayback() {
        player.stop()
        lock.withLock { pendingBuffers = 0 }
        player.play()
        onOutputLevel?(0)
    }
}

// MARK: - Session

@MainActor
@Observable
final class GeminiLiveSession {
    enum State: Equatable { case idle, connecting, live, ended, failed(String) }

    struct Line: Identifiable, Equatable {
        let id = UUID()
        let speaker: Speaker
        var text: String
        enum Speaker { case biographer, storyteller }
    }

    struct Turn: Codable { var text: String; var start: Double; var end: Double }

    private(set) var state: State = .idle
    private(set) var lines: [Line] = []
    private(set) var storytellerTurns: [Turn] = []
    private(set) var inputLevel: Float = 0
    private(set) var outputLevel: Float = 0
    private(set) var startedAt: Date?
    private(set) var recordingURL: URL?

    private var socket: URLSessionWebSocketTask?
    private let audio = LiveAudioIO()
    private var receiveTask: Task<Void, Never>?
    private var openTurn = false

    var isBiographerSpeaking: Bool { outputLevel > 0.02 }

    func setMuted(_ muted: Bool) { audio.muted = muted }

    func start(systemPrompt: String, kickoff: String, voice: String = "Sulafat") async {
        guard let key = Config.geminiAPIKey else {
            state = .failed("Add your Gemini API key (Secrets.plist) to talk with Louise.")
            return
        }
        state = .connecting
        guard await AVAudioApplication.requestRecordPermission() else {
            state = .failed("Microphone access is needed for the test call.")
            return
        }

        let url = URL(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(key)")!
        let ws = URLSession.shared.webSocketTask(with: url)
        ws.maximumMessageSize = 16 * 1024 * 1024
        socket = ws
        ws.resume()

        var generation: [String: Any] = [
            "responseModalities": ["AUDIO"],
            "speechConfig": ["voiceConfig": ["prebuiltVoiceConfig": ["voiceName": voice]]],
        ]
        if Config.liveModel.contains("extended-thinking") {
            generation["thinkingConfig"] = ["thinkingLevel": Config.liveThinkingLevel]
        }
        let setup: [String: Any] = ["setup": [
            "model": "models/\(Config.liveModel)",
            "generationConfig": generation,
            "systemInstruction": ["parts": [["text": systemPrompt]]],
            "inputAudioTranscription": [:],
            "outputAudioTranscription": [:],
            // Elderly storytellers pause mid-sentence: wait much longer before taking the turn.
            "realtimeInputConfig": ["automaticActivityDetection": [
                "startOfSpeechSensitivity": "START_SENSITIVITY_HIGH",
                "endOfSpeechSensitivity": "END_SENSITIVITY_LOW",
                "prefixPaddingMs": 300,
                "silenceDurationMs": 1600,
            ]],
            "contextWindowCompression": ["slidingWindow": [:]],
        ]]
        send(setup)

        receiveTask = Task { [weak self] in await self?.receiveLoop(kickoff: kickoff) }
    }

    func end() {
        receiveTask?.cancel()
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        audio.stop()
        closeTurn()
        if case .failed = state {} else { state = .ended }
    }

    // MARK: Private

    private func beginAudio() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let file = dir.appendingPathComponent("rec-\(Int(Date().timeIntervalSince1970)).wav")
        recordingURL = file
        audio.onChunk = { [weak self] data, level in
            let msg = "{\"realtimeInput\":{\"audio\":{\"data\":\"\(data.base64EncodedString())\",\"mimeType\":\"audio/pcm;rate=16000\"}}}"
            self?.socketSend(msg)
            Task { @MainActor in self?.inputLevel = level }
        }
        audio.onOutputLevel = { [weak self] level in
            Task { @MainActor in self?.outputLevel = level }
        }
        do {
            try audio.start(recordingTo: file)
            startedAt = .now
            state = .live
        } catch {
            state = .failed("Audio error: \(error.localizedDescription)")
        }
    }

    nonisolated private func socketSend(_ text: String) {
        Task { @MainActor [weak self] in self?.socket?.send(.string(text)) { _ in } }
    }

    private func send(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return }
        socket?.send(.string(text)) { _ in }
    }

    private func receiveLoop(kickoff: String) async {
        while !Task.isCancelled, let socket {
            do {
                let message = try await socket.receive()
                let data: Data
                switch message {
                case .string(let s): data = Data(s.utf8)
                case .data(let d): data = d
                @unknown default: continue
                }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                handle(json, kickoff: kickoff)
            } catch {
                if state == .live || state == .connecting {
                    let reason = socket.closeReason.flatMap { String(data: $0, encoding: .utf8) } ?? error.localizedDescription
                    state = .failed(reason.isEmpty ? "Connection closed" : reason)
                    audio.stop()
                }
                return
            }
        }
    }

    private func handle(_ json: [String: Any], kickoff: String) {
        if json["setupComplete"] != nil {
            beginAudio()
            send(["clientContent": ["turns": [["role": "user", "parts": [["text": kickoff]]]], "turnComplete": true]])
            return
        }
        guard let content = json["serverContent"] as? [String: Any] else { return }

        if let turn = content["modelTurn"] as? [String: Any], let parts = turn["parts"] as? [[String: Any]] {
            for part in parts {
                if let inline = part["inlineData"] as? [String: Any],
                   let b64 = inline["data"] as? String, let pcm = Data(base64Encoded: b64) {
                    closeTurn()
                    audio.play(pcm16: pcm)
                }
            }
        }
        if let t = (content["outputTranscription"] as? [String: Any])?["text"] as? String {
            closeTurn()
            append(t, .biographer)
        }
        if let t = (content["inputTranscription"] as? [String: Any])?["text"] as? String {
            append(t, .storyteller)
            let now = audio.recordedSeconds
            if openTurn, !storytellerTurns.isEmpty {
                storytellerTurns[storytellerTurns.count - 1].text += t
                storytellerTurns[storytellerTurns.count - 1].end = now
            } else {
                storytellerTurns.append(Turn(text: t, start: max(0, now - 1.5), end: now))
                openTurn = true
            }
        }
        if content["interrupted"] as? Bool == true {
            audio.flushPlayback()
        }
    }

    private func closeTurn() {
        guard openTurn else { return }
        openTurn = false
        if !storytellerTurns.isEmpty {
            storytellerTurns[storytellerTurns.count - 1].end = audio.recordedSeconds
        }
    }

    private func append(_ text: String, _ speaker: Line.Speaker) {
        if let last = lines.last, last.speaker == speaker {
            // Fragments sometimes arrive without the space after punctuation ("Jeanne.It's").
            var piece = text
            if let end = last.text.last, ".,!?;:".contains(end), let first = piece.first, first.isLetter { piece = " " + piece }
            lines[lines.count - 1].text += piece
        } else {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            lines.append(Line(speaker: speaker, text: trimmed))
        }
    }
}
