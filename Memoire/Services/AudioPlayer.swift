import AVFoundation
import SwiftUI

/// Single shared player: one voice at a time, like a record player in the living room.
@MainActor
@Observable
final class AudioPlayer {
    static let shared = AudioPlayer()

    private(set) var story: Story?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    /// Optional end bound when playing an archive excerpt.
    private(set) var clipEnd: TimeInterval?

    private var player: AVAudioPlayer?
    private var timer: Timer?

    var progress: Double { duration > 0 ? currentTime / duration : 0 }

    var activeSegmentIndex: Int? {
        guard let story else { return nil }
        return story.segments.lastIndex { $0.start <= currentTime + 0.05 }
    }

    func isCurrent(_ s: Story) -> Bool { story?.id == s.id }

    func toggle(_ s: Story) {
        if isCurrent(s) { isPlaying ? pause() : resume() } else { play(s) }
    }

    func play(_ s: Story, from start: TimeInterval = 0, until end: TimeInterval? = nil) {
        if !isCurrent(s) {
            stop()
            guard let url = s.audioURL, let p = try? AVAudioPlayer(contentsOf: url) else { return }
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try? AVAudioSession.sharedInstance().setActive(true)
            p.prepareToPlay()
            player = p
            story = s
            duration = p.duration
        }
        clipEnd = end
        seek(to: start)
        resume()
    }

    func resume() {
        guard let player else { return }
        player.play()
        isPlaying = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func stop() {
        player?.stop()
        player = nil
        story = nil
        isPlaying = false
        currentTime = 0
        clipEnd = nil
        timer?.invalidate()
    }

    func seek(to t: TimeInterval) {
        player?.currentTime = max(0, min(t, duration))
        currentTime = player?.currentTime ?? 0
    }

    func skip(_ delta: TimeInterval) { seek(to: currentTime + delta) }

    private func tick() {
        guard let player else { return }
        currentTime = player.currentTime
        if let clipEnd, currentTime >= clipEnd { pause(); self.clipEnd = nil }
        if !player.isPlaying && isPlaying { isPlaying = false; timer?.invalidate() }
    }
}
