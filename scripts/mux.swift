// Mux a silent simulator recording with captured system audio.
// Usage: mux video.mp4 audio.m4a <audioStartMinusVideoStartSeconds> out.mp4
import AVFoundation
let a = CommandLine.arguments
let video = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let audio = AVURLAsset(url: URL(fileURLWithPath: a[2]))
let offset = Double(a[3])!
let out = URL(fileURLWithPath: a[4])
try? FileManager.default.removeItem(at: out)
let sem = DispatchSemaphore(value: 0)
Task {
    let comp = AVMutableComposition()
    let vTrack = try await video.loadTracks(withMediaType: .video)[0]
    let vDur = try await video.load(.duration)
    let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try cv.insertTimeRange(CMTimeRange(start: .zero, duration: vDur), of: vTrack, at: .zero)
    cv.preferredTransform = try await vTrack.load(.preferredTransform)
    let aTrack = try await audio.loadTracks(withMediaType: .audio)[0]
    let aDur = try await audio.load(.duration)
    let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    var srcStart = CMTime.zero, dst = CMTime(seconds: max(0, offset), preferredTimescale: 600)
    if offset < 0 { srcStart = CMTime(seconds: -offset, preferredTimescale: 600) }
    let len = CMTimeMinimum(CMTimeSubtract(aDur, srcStart), CMTimeSubtract(vDur, dst))
    try ca.insertTimeRange(CMTimeRange(start: srcStart, duration: len), of: aTrack, at: dst)
    let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
    try await ex.export(to: out, as: .mp4)
    print("wrote \(out.path)")
    sem.signal()
}
sem.wait()
