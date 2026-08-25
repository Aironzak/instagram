// Собирает то, что зритель видит в герое: кадр + затемняющие градиенты + подпись.
// Нужен потому, что скриншоты встроенной панели браузера приходят затемнёнными
// и по ним нельзя судить о реальном виде страницы.
//
//   swiftc -O preview_hero.swift -o preview_hero
//   ./preview_hero frames/frame_0180.jpg out.png "Столы" "на заказ по размеру"

import AppKit
import CoreImage
import CoreGraphics
import Foundation

func fail(_ m: String) -> Never {
    FileHandle.standardError.write((m + "\n").data(using: .utf8)!)
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else {
    fail("использование: preview_hero <кадр.jpg> <выход.png> [подпись] [примечание]")
}
let inURL = URL(fileURLWithPath: args[0])
let outURL = URL(fileURLWithPath: args[1])
let caption = args.count > 2 ? args[2] : ""
let note = args.count > 3 ? args[3] : ""

guard let src = CGImageSourceCreateWithURL(inURL as CFURL, nil),
      let frame = CGImageSourceCreateImageAtIndex(src, 0, nil)
else { fail("не читается кадр: \(inURL.path)") }

// Кадр рисуется в холст 16:9 по правилу cover, как это делает CSS.
let W = 1280, H = 720
guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8,
                          bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fail("не создаётся контекст") }

// filter: brightness(1.14) saturate(1.05) — тот же подъём, что задан кадру в CSS.
let lifted: CGImage = {
    guard let ci = CIImage(cgImage: frame) as CIImage?,
          let f = CIFilter(name: "CIColorControls") else { return frame }
    f.setValue(ci, forKey: kCIInputImageKey)
    f.setValue(0.07, forKey: kCIInputBrightnessKey)
    f.setValue(1.05, forKey: kCIInputSaturationKey)
    guard let out = f.outputImage,
          let cg = CIContext().createCGImage(out, from: out.extent) else { return frame }
    return cg
}()

let scale = max(CGFloat(W) / CGFloat(frame.width), CGFloat(H) / CGFloat(frame.height))
let dw = CGFloat(frame.width) * scale, dh = CGFloat(frame.height) * scale
ctx.draw(lifted, in: CGRect(x: (CGFloat(W) - dw) / 2, y: (CGFloat(H) - dh) / 2, width: dw, height: dh))

// Те же два градиента, что в .stage__scrim. Начало координат снизу.
let dark = CGColorSpaceCreateDeviceRGB()
func gradient(_ stops: [(CGFloat, CGFloat)]) -> CGGradient? {
    var comps: [CGFloat] = []
    var locs: [CGFloat] = []
    for (loc, alpha) in stops {
        comps += [CGFloat(10) / 255, CGFloat(8) / 255, CGFloat(6) / 255, alpha]
        locs.append(loc)
    }
    return CGGradient(colorSpace: dark, colorComponents: comps, locations: locs, count: stops.count)
}

// сверху вниз: .30 -> 0 к 14 %
if let g = gradient([(0, 0.30), (1, 0)]) {
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: CGFloat(H) * 0.86, width: CGFloat(W), height: CGFloat(H) * 0.14))
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: CGFloat(H)),
                           end: CGPoint(x: 0, y: CGFloat(H) * 0.86), options: [])
    ctx.restoreGState()
}
// снизу вверх: .58 -> .12 на 26 % -> 0 на 42 %
if let g = gradient([(0, 0.58), (0.26 / 0.42, 0.12), (1, 0)]) {
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: 0, width: CGFloat(W), height: CGFloat(H) * 0.42))
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 0),
                           end: CGPoint(x: 0, y: CGFloat(H) * 0.42), options: [])
    ctx.restoreGState()
}

// Подпись: рисуем в NSImage и подкладываем, чтобы получить настоящие шрифт и тень.
func draw(_ text: String, size: CGFloat, colour: NSColor, y: CGFloat, tracking: CGFloat = 0) {
    guard !text.isEmpty else { return }
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.9)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = .zero
    let font = NSFont(name: "Georgia-Bold", size: size) ?? NSFont.boldSystemFont(ofSize: size)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: colour, .shadow: shadow, .kern: tracking,
    ]
    let s = NSAttributedString(string: text, attributes: attrs)
    let bounds = s.size()
    let img = NSImage(size: NSSize(width: W, height: Int(bounds.height) + 40))
    img.lockFocus()
    s.draw(at: NSPoint(x: (CGFloat(W) - bounds.width) / 2, y: 20))
    img.unlockFocus()
    if let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        ctx.draw(cg, in: CGRect(x: 0, y: y, width: CGFloat(W), height: bounds.height + 40))
    }
}

draw(caption, size: 58, colour: NSColor(calibratedRed: 0.96, green: 0.945, blue: 0.918, alpha: 1), y: CGFloat(H) * 0.12)
draw(note.uppercased(), size: 15, colour: NSColor(calibratedRed: 0.784, green: 0.604, blue: 0.416, alpha: 1),
     y: CGFloat(H) * 0.075, tracking: 4)

guard let out = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil)
else { fail("не удалось собрать изображение") }
CGImageDestinationAddImage(dest, out, nil)
guard CGImageDestinationFinalize(dest) else { fail("не записался \(outURL.path)") }
print("готово: \(outURL.path)")
