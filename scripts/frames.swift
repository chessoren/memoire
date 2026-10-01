// Extract full-res frames: frames video.mp4 outdir name:t name:t ...
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
let a = CommandLine.arguments
let gen = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: a[1])))
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
let sem = DispatchSemaphore(value: 0)
Task {
    for spec in a.dropFirst(3) {
        let p = spec.split(separator: ":"); let t = Double(p[1])!
        guard let (cg, _) = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)) else { continue }
        let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(a[2])/\(p[0]).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, cg, nil); CGImageDestinationFinalize(d)
    }
    sem.signal()
}
sem.wait()
