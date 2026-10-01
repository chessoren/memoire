// Contact sheet: one thumbnail every N seconds, 10 per row (row r, col c => t = (r*10+c)*step).
// Usage: contact in.mp4 out.png step
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let a = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let step = Double(a[3])!
let gen = AVAssetImageGenerator(asset: asset)
gen.maximumSize = CGSize(width: 160, height: 348)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
let sem = DispatchSemaphore(value: 0)
Task {
    let dur = (try? await asset.load(.duration).seconds) ?? 0
    let times = Array(stride(from: 0.0, to: dur, by: step))
    let cols = 10, w = 160, h = 348, gap = 6
    let rows = (times.count + cols - 1) / cols
    let W = cols * (w + gap), H = rows * (h + gap)
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    for (i, t) in times.enumerated() {
        guard let (cg, _) = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)) else { continue }
        let x = (i % cols) * (w + gap), y = H - (i / cols + 1) * (h + gap)
        ctx.draw(cg, in: CGRect(x: x, y: y, width: w, height: h))
    }
    let out = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, out, nil)
    CGImageDestinationFinalize(dest)
    print("rows \(rows), frames \(times.count)")
    sem.signal()
}
sem.wait()
