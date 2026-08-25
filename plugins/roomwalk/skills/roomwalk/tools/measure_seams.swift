// Меряет, насколько плотно сходятся стыки между сегментами прохода.
//
//   swiftc -O measure_seams.swift -o measure_seams
//   ./measure_seams ./frames 120
//
// Второй аргумент — длина сегмента в кадрах. На каждой границе сравнивает
// последний кадр сегмента со первым кадром следующего и сопоставляет разрыв
// с типичной разницей соседних кадров внутри сегментов. Отношение около
// единицы означает, что стык неотличим от обычной смены кадра.

import CoreGraphics
import Foundation
import ImageIO

func fail(_ m: String) -> Never {
    FileHandle.standardError.write((m + "\n").data(using: .utf8)!)
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2, let seg = Int(args[1]) else {
    fail("использование: measure_seams <папка с кадрами> <кадров в сегменте>")
}
let dir = URL(fileURLWithPath: args[0], isDirectory: true)

let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
    .filter { $0.pathExtension.lowercased() == "jpg" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

guard files.count > seg else { fail("кадров меньше, чем длина сегмента") }

/// Уменьшенная копия кадра в оттенках серого — достаточно, чтобы сравнить композицию.
func thumb(_ url: URL, side: Int = 48) -> [Double]? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateThumbnailAtIndex(src, 0, [
              kCGImageSourceCreateThumbnailFromImageAlways: true,
              kCGImageSourceThumbnailMaxPixelSize: side,
              kCGImageSourceCreateThumbnailWithTransform: true,
          ] as CFDictionary)
    else { return nil }

    let w = img.width, h = img.height
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

    var out = [Double]()
    out.reserveCapacity(w * h)
    for i in stride(from: 0, to: buf.count, by: 4) {
        out.append(0.299 * Double(buf[i]) + 0.587 * Double(buf[i + 1]) + 0.114 * Double(buf[i + 2]))
    }
    return out
}

func rms(_ a: [Double], _ b: [Double]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return .nan }
    var s = 0.0
    for i in 0..<a.count { s += (a[i] - b[i]) * (a[i] - b[i]) }
    return (s / Double(a.count)).squareRoot()
}

print("кадров \(files.count), сегментов \(files.count / seg)\n")

var thumbs = [[Double]]()
for f in files {
    guard let t = thumb(f) else { fail("не читается \(f.lastPathComponent)") }
    thumbs.append(t)
}

// Типичная разница соседних кадров ВНУТРИ сегментов — это норма, с которой сравниваем.
var inside = [Double]()
for i in 1..<thumbs.count where i % seg != 0 {
    inside.append(rms(thumbs[i - 1], thumbs[i]))
}
let median = inside.sorted()[inside.count / 2]

func f(_ v: Double) -> String { String(format: "%.2f", v) }

print("типичная смена кадра внутри сегмента: \(f(median))\n")
print("стык        разрыв    отношение")

var worst = 0.0
var k = seg
while k < thumbs.count {
    let gap = rms(thumbs[k - 1], thumbs[k])
    let ratio = median > 0 ? gap / median : .nan
    if ratio > worst { worst = ratio }
    let mark = ratio < 2 ? "незаметен" : (ratio < 5 ? "слегка виден" : "рвётся")
    print("\(k - 1)|\(k)".padding(toLength: 12, withPad: " ", startingAt: 0)
          + f(gap).padding(toLength: 10, withPad: " ", startingAt: 0)
          + "\(f(ratio))×  \(mark)")
    k += seg
}

print("\nхудший стык: \(f(worst))×")
if worst < 2 {
    print("Все стыки в пределах обычной смены кадра.")
} else if worst < 5 {
    print("Есть заметные стыки — стоит перегенерить именно их.")
} else {
    print("Стыки рвутся: сегменты не сходятся по композиции.")
}
