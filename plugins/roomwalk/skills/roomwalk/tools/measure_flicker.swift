// Меряет покадровое мерцание в последовательности кадров.
//
//   swiftc -O measure_flicker.swift -o measure_flicker
//   ./measure_flicker ./frames
//
// Считает среднюю яркость каждого кадра и разброс скачков яркости между
// соседними кадрами. Именно эти скачки видны как мерцание при медленной
// промотке скроллом, хотя на воспроизведении 24-30 fps они незаметны.
// Также сравнивает первый и последний кадр — это стык лупа.

import CoreGraphics
import Foundation
import ImageIO

func fail(_ m: String) -> Never {
    FileHandle.standardError.write((m + "\n").data(using: .utf8)!)
    exit(1)
}

guard CommandLine.arguments.count >= 2 else {
    fail("использование: measure_flicker <папка с кадрами>")
}
let dir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
    .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

guard files.count > 2 else { fail("в папке меньше трёх кадров") }

/// Средняя яркость кадра в диапазоне 0..255, плюс уменьшенная копия для сравнения кадров.
func analyze(_ url: URL, thumb side: Int = 32) -> (mean: Double, pixels: [Double])? {
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
                              bytesPerRow: w * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

    var lum = [Double]()
    lum.reserveCapacity(w * h)
    for i in stride(from: 0, to: buf.count, by: 4) {
        // Rec. 601 — та же формула, по которой глаз взвешивает каналы.
        lum.append(0.299 * Double(buf[i]) + 0.587 * Double(buf[i + 1]) + 0.114 * Double(buf[i + 2]))
    }
    return (lum.reduce(0, +) / Double(lum.count), lum)
}

var means = [Double]()
var thumbs = [[Double]]()
for f in files {
    guard let a = analyze(f) else { fail("не читается \(f.lastPathComponent)") }
    means.append(a.mean)
    thumbs.append(a.pixels)
}

// Скачки яркости между соседними кадрами.
var deltas = [Double]()
for i in 1..<means.count { deltas.append(abs(means[i] - means[i - 1])) }

let meanDelta = deltas.reduce(0, +) / Double(deltas.count)
let maxDelta = deltas.max() ?? 0
let variance = deltas.map { pow($0 - meanDelta, 2) }.reduce(0, +) / Double(deltas.count)
let sdDelta = sqrt(variance)

// Стык лупа: насколько последний кадр отличается от первого.
func rms(_ a: [Double], _ b: [Double]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return .nan }
    var s = 0.0
    for i in 0..<a.count { s += pow(a[i] - b[i], 2) }
    return sqrt(s / Double(a.count))
}
let seamRMS = rms(thumbs.first!, thumbs.last!)

// Для сравнения — типичный разрыв между двумя соседними кадрами в середине.
var neighbourRMS = [Double]()
for i in 1..<thumbs.count { neighbourRMS.append(rms(thumbs[i - 1], thumbs[i])) }
let medianNeighbour = neighbourRMS.sorted()[neighbourRMS.count / 2]

func f(_ v: Double, _ d: Int = 2) -> String { String(format: "%.\(d)f", v) }

print("кадров: \(files.count)")
print("яркость: мин \(f(means.min()!)), макс \(f(means.max()!)), средняя \(f(means.reduce(0,+)/Double(means.count)))")
print("")
print("МЕРЦАНИЕ (скачок яркости между соседними кадрами, 0..255)")
print("  средний    \(f(meanDelta, 3))")
print("  максимум   \(f(maxDelta, 3))")
print("  разброс    \(f(sdDelta, 3))")
print("")
print("СТЫК ЛУПА (RMS-разница картинок, 0..255)")
print("  последний против первого   \(f(seamRMS))")
print("  типичная пара соседей      \(f(medianNeighbour))")
let ratio = medianNeighbour > 0 ? seamRMS / medianNeighbour : .nan
print("  отношение                  \(f(ratio))x")
print("")
if ratio < 2 {
    print("Стык незаметен: переход через границу лупа не грубее обычной смены кадров.")
} else if ratio < 5 {
    print("Стык слегка виден — на медленной промотке может читаться толчок.")
} else {
    print("Стык рвётся: последний кадр далеко от первого, луп будет дёргаться.")
}
