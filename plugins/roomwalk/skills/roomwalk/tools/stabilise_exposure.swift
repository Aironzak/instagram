// Убирает «уплывающий свет» из последовательности кадров.
//
//   swiftc -O stabilise_exposure.swift -o stabilise_exposure
//   ./stabilise_exposure ./frames
//
// Модель сама переосвещает сцену внутри дубля: за восемь секунд средняя яркость
// уезжает на десятки единиц. На воспроизведении это незаметно, а при медленной
// промотке скроллом читается как «солнце появилось и ушло».
//
// Каждый кадр умножается на коэффициент, подтягивающий его среднюю яркость к общей
// медиане. Коэффициент ограничен, чтобы намеренно тёмные места — нутро шкафа, тень
// под столешницей — остались тёмными, а не выровнялись в кисель.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ m: String) -> Never {
    FileHandle.standardError.write((m + "\n").data(using: .utf8)!)
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else { fail("использование: stabilise_exposure <папка> [мин 0.75] [макс 1.35]") }
let dir = URL(fileURLWithPath: args[0], isDirectory: true)
let gainMin = args.count > 1 ? Double(args[1]) ?? 0.75 : 0.75
let gainMax = args.count > 2 ? Double(args[2]) ?? 1.35 : 1.35

let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
    .filter { $0.pathExtension.lowercased() == "jpg" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !files.isEmpty else { fail("кадров не найдено") }

func load(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func pixels(_ img: CGImage) -> (buf: [UInt8], w: Int, h: Int)? {
    let w = img.width, h = img.height
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (buf, w, h)
}

// Первый проход — средняя яркость каждого кадра.
print("читаю \(files.count) кадров…")
var means = [Double]()
for f in files {
    guard let img = load(f), let p = pixels(img) else { fail("не читается \(f.lastPathComponent)") }
    var s = 0.0
    var n = 0
    for i in stride(from: 0, to: p.buf.count, by: 4 * 37) {
        s += 0.299 * Double(p.buf[i]) + 0.587 * Double(p.buf[i + 1]) + 0.114 * Double(p.buf[i + 2])
        n += 1
    }
    means.append(s / Double(n))
}

let target = means.sorted()[means.count / 2]
print(String(format: "цель: %.1f  (было %.1f…%.1f)", target, means.min()!, means.max()!))

// Второй проход — применяем коэффициент.
var clamped = 0
for (i, f) in files.enumerated() {
    var gain = target / max(means[i], 1)
    if gain < gainMin { gain = gainMin; clamped += 1 }
    if gain > gainMax { gain = gainMax; clamped += 1 }
    if abs(gain - 1) < 0.004 { continue }

    guard let img = load(f), var p = pixels(img) else { continue }
    // Таблица на 256 значений — считать степень для каждого пикселя незачем.
    var lut = [UInt8](repeating: 0, count: 256)
    for v in 0..<256 {
        lut[v] = UInt8(max(0, min(255, (Double(v) * gain).rounded())))
    }
    for j in stride(from: 0, to: p.buf.count, by: 4) {
        p.buf[j] = lut[Int(p.buf[j])]
        p.buf[j + 1] = lut[Int(p.buf[j + 1])]
        p.buf[j + 2] = lut[Int(p.buf[j + 2])]
    }
    guard let ctx = CGContext(data: &p.buf, width: p.w, height: p.h, bitsPerComponent: 8,
                              bytesPerRow: p.w * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let out = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(
              f as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { continue }
    CGImageDestinationAddImage(dest, out, [kCGImageDestinationLossyCompressionQuality: 0.72] as CFDictionary)
    CGImageDestinationFinalize(dest)
}

print("готово. кадров с упёршимся коэффициентом: \(clamped) — там свет намеренно другой")
