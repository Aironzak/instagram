// Смягчает стык между сегментами, подмешивая кадры друг в друга.
//
//   swiftc -O blend_seam.swift -o blend_seam
//   ./blend_seam ./frames 480 8
//
// Аргументы: папка с кадрами, номер первого кадра второго сегмента, ширина
// зоны смешивания в кадрах. Кадры по обе стороны от стыка переписываются
// смесью, вес которой плавно переходит от одного сегмента к другому.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ m: String) -> Never {
    FileHandle.standardError.write((m + "\n").data(using: .utf8)!)
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 3, let seam = Int(args[1]), let span = Int(args[2]), span > 0 else {
    fail("использование: blend_seam <папка> <кадр стыка> <ширина зоны>")
}
let dir = URL(fileURLWithPath: args[0], isDirectory: true)
let pattern = "frame_%04d.jpg"

func url(_ i: Int) -> URL { dir.appendingPathComponent(String(format: pattern, i)) }

func load(_ i: Int) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url(i) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func write(_ img: CGImage, _ i: Int) {
    guard let dest = CGImageDestinationCreateWithURL(
        url(i) as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: 0.72] as CFDictionary)
    CGImageDestinationFinalize(dest)
}

// Опорные кадры по обе стороны стыка: последний кадр «до» и первый кадр «после».
guard let before = load(seam - 1), let after = load(seam) else {
    fail("не читаются кадры вокруг стыка \(seam)")
}
let W = before.width, H = before.height

var written = 0
for k in -span...(span - 1) {
    let idx = seam + k
    guard let base = load(idx) else { continue }
    // Вес чужого кадра растёт к стыку и спадает от него.
    let t = Double(k + span) / Double(2 * span)          // 0…1 через зону
    let alpha = k < 0 ? t * 0.5 : (1 - t) * 0.5          // максимум 0.5 в самом стыке
    let other = k < 0 ? after : before

    guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { continue }
    let rect = CGRect(x: 0, y: 0, width: W, height: H)
    ctx.draw(base, in: rect)
    ctx.setAlpha(CGFloat(alpha))
    ctx.draw(other, in: rect)
    if let out = ctx.makeImage() { write(out, idx); written += 1 }
}

print("смешано кадров: \(written) вокруг стыка \(seam)")
