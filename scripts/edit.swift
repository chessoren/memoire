// Assemble the demo video from simulator takes: cuts, speed-ups, branded canvas, captions.
// Usage: edit edl.json out.mp4
// edl.json: {"clips":[{"file":"demo/take2.mp4","start":6,"end":21,"speed":1,"caption":"..."}]}
import AVFoundation
import CoreImage
import CoreText
import AppKit

struct Clip: Decodable { let file: String; let start: Double; let end: Double; let speed: Double?; let caption: String? }
struct EDL: Decodable { let clips: [Clip] }

let args = CommandLine.arguments
let edl = try! JSONDecoder().decode(EDL.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let out = URL(fileURLWithPath: args[2])
try? FileManager.default.removeItem(at: out)

let W: CGFloat = 1080, H: CGFloat = 1920, captionH: CGFloat = 300
let sem = DispatchSemaphore(value: 0)

Task {
    let comp = AVMutableComposition()
    let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    var cursor = CMTime.zero
    var captions: [(String, Double, Double)] = []
    var natural = CGSize(width: 1206, height: 2622)

    for c in edl.clips {
        let asset = AVURLAsset(url: URL(fileURLWithPath: c.file))
        let sv = try await asset.loadTracks(withMediaType: .video)[0]
        natural = try await sv.load(.naturalSize)
        let range = CMTimeRange(start: CMTime(seconds: c.start, preferredTimescale: 600),
                                end: CMTime(seconds: c.end, preferredTimescale: 600))
        try vTrack.insertTimeRange(range, of: sv, at: cursor)
        if let sa = try await asset.loadTracks(withMediaType: .audio).first {
            try? aTrack.insertTimeRange(range, of: sa, at: cursor)
        }
        var dur = range.duration
        if let s = c.speed, s != 1 {
            let scaled = CMTimeMultiplyByFloat64(dur, multiplier: 1 / s)
            vTrack.scaleTimeRange(CMTimeRange(start: cursor, duration: dur), toDuration: scaled)
            aTrack.scaleTimeRange(CMTimeRange(start: cursor, duration: dur), toDuration: scaled)
            dur = scaled
        }
        if let cap = c.caption { captions.append((cap, cursor.seconds, (cursor + dur).seconds)) }
        cursor = cursor + dur
    }
    print(String(format: "total %.1fs", cursor.seconds))

    // Per-frame Core Image compositing: gradient canvas, phone recording, caption band.
    let availH = H - captionH - 60
    let scale = availH / natural.height
    let phoneW = natural.width * scale
    let bgImage = CIFilter(name: "CILinearGradient", parameters: [
        "inputPoint0": CIVector(x: 0, y: H), "inputColor0": CIColor(red: 0.04, green: 0.47, blue: 1),
        "inputPoint1": CIVector(x: 0, y: 0), "inputColor1": CIColor(red: 0.62, green: 0.82, blue: 1),
    ])!.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
    let brand = textImage("Mémoire", size: 40, weight: .heavy, alpha: 0.85, box: CGSize(width: W, height: 60))
        .transformed(by: CGAffineTransform(translationX: 0, y: H - 80))
    let capImages = captions.map { (textImage($0.0, size: 54, weight: .bold, alpha: 1, box: CGSize(width: W - 120, height: captionH - 90))
        .transformed(by: CGAffineTransform(translationX: 60, y: H - captionH - 20)), $0.1, $0.2) }
    let base = brand.composited(over: bgImage)

    let video = AVMutableVideoComposition(asset: comp) { req in
        let t = req.compositionTime.seconds
        let phone = req.sourceImage
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: (W - phoneW) / 2, y: 40))
        var frame = phone.composited(over: base)
        for (img, s, e) in capImages where t >= s && t < e {
            let fade = min(1, min(t - s, e - t) / 0.3)
            let faded = img.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: fade)])
            frame = faded.composited(over: frame)
        }
        req.finish(with: frame.cropped(to: CGRect(x: 0, y: 0, width: W, height: H)), context: nil)
    }
    video.renderSize = CGSize(width: W, height: H)
    video.frameDuration = CMTime(value: 1, timescale: 30)

    let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
    ex.videoComposition = video
    do { try await ex.export(to: out, as: .mp4); print("wrote \(out.path)") }
    catch { print("export error: \(error)") }
    sem.signal()
}
sem.wait()

/// Centered, wrapped white text rendered with CoreText into a transparent CIImage.
func textImage(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, box: CGSize) -> CIImage {
    let ctx = CGContext(data: nil, width: Int(box.width), height: Int(box.height), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attr = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(white: 1, alpha: alpha),
        .paragraphStyle: para,
    ])
    let framesetter = CTFramesetterCreateWithAttributedString(attr)
    let fit = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil, box, nil)
    let y = (box.height - fit.height) / 2
    let path = CGPath(rect: CGRect(x: 0, y: y, width: box.width, height: fit.height + 2), transform: nil)
    CTFrameDraw(CTFramesetterCreateFrame(framesetter, CFRange(), path, nil), ctx)
    return CIImage(cgImage: ctx.makeImage()!)
}
