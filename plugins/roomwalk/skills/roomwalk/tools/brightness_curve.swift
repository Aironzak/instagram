// Печатает кривую средней яркости по кадрам — чтобы увидеть, где сцена
// «подсвечивается» сама собой посреди дубля.
//
//   swiftc -O brightness_curve.swift -o brightness_curve
//   ./brightness_curve ./frames 120      # второй аргумент: длина сегмента

import CoreGraphics
import Foundation
import ImageIO

func fail(_ m: String) -> Never {
    FileHandle.standardError.write((m + "\n").data(using: .utf8)!)
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else { fail("использование: brightness_curve <папка> [кадров в сегменте]") }
let dir = URL(fileURLWithPath: args[0], isDirectory: true)
let seg = args.count > 1 ? Int(args[1]) ?? 0 : 0

let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
    .filter { $0.pathExtension.lowercased() == "jpg" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !files.isEmpty else { fail("кадров не найдено") }

func meanLuma(_ url: URL) -> Double? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateThumbnailAtIndex(src, 0, [
              kCGImageSourceCreateThumbnailFromImageAlways: true,
              kCGImageSourceThumbnailMaxPixelSize: 40,
          ] as CFDictionary) else { return nil }
    let w = img.width, h = img.height
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    var s = 0.0
    var n = 0
    for i in stride(from: 0, to: buf.count, by: 4) {
        s += 0.299 * Double(buf[i]) + 0.587 * Double(buf[i + 1]) + 0.114 * Double(buf[i + 2])
        n += 1
    }
    return s / Double(n)
}

var vals = [Double]()
for f in files {
    guard let v = meanLuma(f) else { fail("не читается \(f.lastPathComponent)") }
    vals.append(v)
}

let lo = vals.min()!, hi = vals.max()!
func bar(_ v: Double) -> String {
    let n = Int(((v - lo) / max(hi - lo, 0.001)) * 34)
    return String(repeating: "█", count: max(n, 1))
}

print("кадров \(vals.count), яркость \(String(format: "%.1f", lo))…\(String(format: "%.1f", hi))\n")

// Печатаем каждый пятый кадр, чтобы вывод читался.
for (i, v) in vals.enumerated() where i % 5 == 0 {
    let mark = (seg > 0 && i % seg == 0 && i > 0) ? "  ← стык" : ""
    print(String(format: "%4d  %6.1f  ", i, v) + bar(v) + mark)
}

if seg > 0 {
    print("\nпо сегментам:")
    var k = 0
    while k < vals.count {
        let part = Array(vals[k..<min(k + seg, vals.count)])
        let a = part.first!, b = part.last!
        let drift = b - a
        let flag = abs(drift) > 6 ? "  ← свет уезжает" : ""
        print(String(format: "  %3d–%3d   начало %5.1f  конец %5.1f  сдвиг %+5.1f", k, k + part.count - 1, a, b, drift) + flag)
        k += seg
    }
}
