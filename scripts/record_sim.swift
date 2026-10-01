// Records the Simulator window with system audio (ScreenCaptureKit) to an .mp4.
// Usage: swift scripts/record_sim.swift out.mp4   (stop with SIGINT / kill -INT)
import AVFoundation
import Foundation
import ScreenCaptureKit

final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate {
    let writer: AVAssetWriter
    var audioIn: AVAssetWriterInput!
    var stream: SCStream!
    var started = false
    let queue = DispatchQueue(label: "rec")

    init(url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
    }

    func start() async throws {
        // Audio-only: video frames come from `simctl io recordVideo`; we only need system audio here.
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { fputs("no display\n", stderr); exit(2) }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = 64
        config.height = 64
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 2
        config.showsCursor = false

        audioIn = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 160_000,
        ])
        audioIn.expectsMediaDataInRealTime = true
        writer.add(audioIn)

        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await stream.startCapture()
        print("recording \(config.width)x\(config.height)"); fflush(stdout)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sb.isValid else { return }
        guard type == .audio else { return }
        if !started {
            writer.startWriting()
            writer.startSession(atSourceTime: sb.presentationTimeStamp)
            started = true
            print("audio-start \(Date().timeIntervalSince1970)"); fflush(stdout)
        }
        if audioIn.isReadyForMoreMediaData { audioIn.append(sb) }
    }

    func stop() async {
        try? await stream.stopCapture()
        audioIn.markAsFinished()
        await writer.finishWriting()
        print("saved \(writer.outputURL.path)"); fflush(stdout)
    }
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "demo.mp4")
let rec = try Recorder(url: out)
signal(SIGINT, SIG_IGN)
let sig = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sig.setEventHandler { Task { await rec.stop(); exit(0) } }
sig.resume()
Task {
    do { try await rec.start() } catch { fputs("error: \(error)\n", stderr); exit(1) }
}
dispatchMain()
