// Нарезает видео в последовательность кадров для скролл-анимации.
// ffmpeg на этой машине нет — всё на AVFoundation, как и остальной конвейер.
//
//   swiftc -O extract_frames.swift -o extract_frames
//   ./extract_frames in.mp4 ./frames --count 120 --width 1280 --quality 0.72
//
// Пишет frame_0000.jpg... и manifest.json рядом с кадрами.

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Options {
    var input: String
    var outDir: String
    var count: Int = 120
    var width: Int = 1280
    var quality: Double = 0.72
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

func parseArgs() -> Options {
    var args = Array(CommandLine.arguments.dropFirst())
    guard args.count >= 2 else {
        fail("""
        использование: extract_frames <видео> <папка> [--count N] [--width PX] [--quality 0..1]

          --count    сколько кадров вынуть (по умолчанию 120)
          --width    ширина кадра в пикселях, высота по пропорции (по умолчанию 1280)
          --quality  качество JPEG 0..1 (по умолчанию 0.72)
        """)
    }

    var opts = Options(input: args.removeFirst(), outDir: args.removeFirst())

    while !args.isEmpty {
        let flag = args.removeFirst()
        guard !args.isEmpty else { fail("у флага \(flag) нет значения") }
        let value = args.removeFirst()
        switch flag {
        case "--count":   opts.count = Int(value) ?? opts.count
        case "--width":   opts.width = Int(value) ?? opts.width
        case "--quality": opts.quality = Double(value) ?? opts.quality
        default: fail("неизвестный флаг: \(flag)")
        }
    }

    guard opts.count > 1 else { fail("--count должен быть больше 1") }
    guard opts.width > 0 else { fail("--width должен быть положительным") }
    return opts
}

func writeJPEG(_ image: CGImage, to url: URL, quality: Double) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(dest, image, [
        kCGImageDestinationLossyCompressionQuality: quality
    ] as CFDictionary)
    return CGImageDestinationFinalize(dest)
}

let opts = parseArgs()

let inputURL = URL(fileURLWithPath: opts.input)
guard FileManager.default.fileExists(atPath: inputURL.path) else {
    fail("нет файла: \(inputURL.path)")
}

let outURL = URL(fileURLWithPath: opts.outDir, isDirectory: true)
try? FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)

let asset = AVURLAsset(url: inputURL)
let semaphore = DispatchSemaphore(value: 0)

var duration = CMTime.zero
var naturalSize = CGSize.zero
var nominalFPS: Float = 0

Task {
    do {
        duration = try await asset.load(.duration)
        if let track = try await asset.loadTracks(withMediaType: .video).first {
            naturalSize = try await track.load(.naturalSize)
            nominalFPS = try await track.load(.nominalFrameRate)
        }
    } catch {
        fail("не читается видео: \(error.localizedDescription)")
    }
    semaphore.signal()
}
semaphore.wait()

let seconds = CMTimeGetSeconds(duration)
guard seconds.isFinite, seconds > 0, naturalSize.width > 0 else {
    fail("в файле нет видеодорожки или её длительность нулевая")
}

let scale = Double(opts.width) / Double(naturalSize.width)
let outHeight = Int((Double(naturalSize.height) * scale).rounded())

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = CGSize(width: opts.width, height: outHeight)
// Без нулевых допусков генератор отдаёт ближайший keyframe — кадры пойдут дублями,
// и при медленной промотке скроллом анимация встанет ступеньками.
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

// Равномерно по всей длительности. Последний кадр берём с запасом от конца:
// ровно на границе генератор стабильно отдаёт "Cannot Open".
let frameStep = nominalFPS > 0 ? 1.0 / Double(nominalFPS) : 0.04
let lastSafe = max(0, seconds - max(2 * frameStep, 0.05))

let cmTimes: [CMTime] = (0..<opts.count).map { i in
    let t = lastSafe * Double(i) / Double(opts.count - 1)
    return CMTime(seconds: max(0, t), preferredTimescale: 600)
}
let times = cmTimes.map { NSValue(time: $0) }

// Коллбэки прилетают не в том порядке, в каком запрошены, поэтому номер кадра
// восстанавливаем по requestedTime, а не по счётчику вызовов — иначе кадры
// пронумеруются вперемешку и анимация поедет рывками.
var indexByTime: [Int64: Int] = [:]
for (i, t) in cmTimes.enumerated() { indexByTime[t.value] = i }

print("вход:   \(inputURL.lastPathComponent)")
print("исходник: \(Int(naturalSize.width))x\(Int(naturalSize.height)), "
      + String(format: "%.2f", seconds) + " с, "
      + String(format: "%.2f", nominalFPS) + " fps")
print("выход:  \(opts.count) кадров \(opts.width)x\(outHeight) -> \(outURL.path)")

var written = 0
var failed = 0
var index = 0
let done = DispatchSemaphore(value: 0)
let lock = NSLock()

generator.generateCGImagesAsynchronously(forTimes: times) { requested, image, _, result, error in
    let i = indexByTime[requested.value] ?? -1
    lock.lock()
    index += 1
    let seen = index
    lock.unlock()

    switch result {
    case .succeeded:
        if let image {
            let name = String(format: "frame_%04d.jpg", i)
            if writeJPEG(image, to: outURL.appendingPathComponent(name), quality: opts.quality) {
                lock.lock(); written += 1; lock.unlock()
            } else {
                FileHandle.standardError.write("не записался \(name)\n".data(using: .utf8)!)
                lock.lock(); failed += 1; lock.unlock()
            }
        }
    case .failed:
        FileHandle.standardError.write(
            "кадр \(i): \(error?.localizedDescription ?? "неизвестная ошибка")\n".data(using: .utf8)!)
        lock.lock(); failed += 1; lock.unlock()
    default:
        lock.lock(); failed += 1; lock.unlock()
    }

    if seen == times.count { done.signal() }
}

done.wait()

let manifest: [String: Any] = [
    "frames": written,
    "width": opts.width,
    "height": outHeight,
    "pattern": "frame_%04d.jpg",
    "source": inputURL.lastPathComponent,
    "source_duration": seconds,
    "source_fps": Double(nominalFPS),
]
if let data = try? JSONSerialization.data(withJSONObject: manifest,
                                          options: [.prettyPrinted, .sortedKeys]) {
    try? data.write(to: outURL.appendingPathComponent("manifest.json"))
}

let bytes = (try? FileManager.default.contentsOfDirectory(at: outURL, includingPropertiesForKeys: [.fileSizeKey]))?
    .reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) } ?? 0

print("записано \(written), не вышло \(failed), общий вес "
      + String(format: "%.1f", Double(bytes) / 1_048_576) + " МБ")

if failed > 0 { exit(2) }
