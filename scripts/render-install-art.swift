import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Draw in logical points. Finder gets paired 1x/2x artwork; the app icon gets
// every required size from the same paths, with no raster scaling at build time.
func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}
func render(_ width: Int, _ height: Int, scale: Int, to url: URL, draw: (CGContext) -> Void) throws {
    let context = CGContext(data: nil, width: width * scale, height: height * scale,
                            bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(height * scale))
    context.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
    draw(context)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    let density = 72 * scale
    CGImageDestinationAddImage(destination, context.makeImage()!, [
        kCGImagePropertyDPIWidth: density, kCGImagePropertyDPIHeight: density
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}
func label(_ text: String, at point: CGPoint, size: CGFloat, ink: CGColor,
           medium: Bool = false, centered: Bool = false, in c: CGContext) {
    let font = CTFontCreateWithName((medium ? "HelveticaNeue-Medium" : "HelveticaNeue") as CFString, size, nil)
    let attributes = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: ink] as CFDictionary
    let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, text as CFString, attributes)!)
    c.saveGState()
    let offset = centered ? CTLineGetTypographicBounds(line, nil, nil, nil) / 2 : 0
    c.translateBy(x: point.x - offset, y: point.y)
    c.scaleBy(x: 1, y: -1)
    c.textPosition = .zero
    CTLineDraw(line, c)
    c.restoreGState()
}
func background(_ c: CGContext) {
    c.drawLinearGradient(gradient([color(0x234f75), color(0x102c4c), color(0x091c32)]),
                         start: CGPoint(x: 0, y: 0), end: CGPoint(x: 650, y: 450), options: [.drawsAfterEndLocation])
    c.drawRadialGradient(gradient([color(0x87b9e0, 0.20), color(0x87b9e0, 0)]),
                         startCenter: CGPoint(x: 130, y: 45), startRadius: 0,
                         endCenter: CGPoint(x: 130, y: 45), endRadius: 320, options: [])
    // A restrained Aqua arc and two distant, faceted ridges echo the desktop.
    c.setStrokeColor(color(0x86bfee, 0.20)); c.setLineWidth(1.2)
    c.move(to: CGPoint(x: -35, y: 320))
    c.addCurve(to: CGPoint(x: 690, y: 88), control1: CGPoint(x: 196, y: 177), control2: CGPoint(x: 418, y: 120))
    c.strokePath()
    for (ridge, ink) in [
        ([(0, 370),(96, 330),(170, 366),(241, 309),(335, 366),(435, 316),(534, 365),(602, 334),(660, 355)], color(0x5683a9, 0.19)),
        ([(0, 411),(97, 368),(205, 416),(311, 368),(410, 400),(525, 358),(660, 403)], color(0x071a2c, 0.40))
    ] {
        c.setFillColor(ink); c.beginPath(); c.move(to: CGPoint(x: 0, y: 440))
        for (x, y) in ridge { c.addLine(to: CGPoint(x: x, y: y)) }
        c.addLine(to: CGPoint(x: 660, y: 440)); c.closePath(); c.fillPath()
    }
    for index in 0..<66 {
        let x = CGFloat((index * 113 + 29) % 653)
        let y = CGFloat((index * 73 + 51) % 426)
        if (x < 350 && y < 125) || (y > 337 && x > 110 && x < 550) { continue }
        let size: CGFloat = index.isMultiple(of: 9) ? 2.8 : 1.5
        c.setFillColor(color(0xcce7ff, index.isMultiple(of: 9) ? 0.55 : 0.25))
        c.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
    }
    label("Snowy", at: CGPoint(x: 48, y: 79), size: 47, ink: color(0xf8fcff), medium: true, in: c)
    label("A little winter for your Mac.", at: CGPoint(x: 50, y: 109), size: 17, ink: color(0xc4def1), in: c)
    c.setStrokeColor(color(0xc4def1, 0.23)); c.setLineWidth(1)
    c.move(to: CGPoint(x: 49, y: 135)); c.addLine(to: CGPoint(x: 611, y: 135)); c.strokePath()
    label("Drag Snowy to Applications", at: CGPoint(x: 330, y: 168), size: 17,
          ink: color(0xe8f5ff), medium: true, centered: true, in: c)
    c.setStrokeColor(color(0xbce4ff, 0.78)); c.setLineWidth(3); c.setLineCap(.round); c.setLineJoin(.round)
    c.move(to: CGPoint(x: 285, y: 240)); c.addLine(to: CGPoint(x: 374, y: 240))
    c.move(to: CGPoint(x: 359, y: 226)); c.addLine(to: CGPoint(x: 374, y: 240))
    c.addLine(to: CGPoint(x: 359, y: 254)); c.strokePath()
    label("Then open Snowy from Applications.", at: CGPoint(x: 330, y: 361), size: 15,
          ink: color(0xe8f5ff), centered: true, in: c)
    label("macOS 14 or later", at: CGPoint(x: 330, y: 396), size: 12,
          ink: color(0xb4cde2), centered: true, in: c)
}
func stroke(_ points: [CGPoint], in c: CGContext) {
    guard let first = points.first else { return }
    c.move(to: first)
    for point in points.dropFirst() { c.addLine(to: point) }
    c.strokePath()
}
func icon(_ c: CGContext, size: CGFloat) {
    c.scaleBy(x: size / 1024, y: size / 1024)
    let box = CGRect(x: 64, y: 64, width: 896, height: 896)
    let shape = CGPath(roundedRect: box, cornerWidth: 224, cornerHeight: 224, transform: nil)
    c.setFillColor(color(0x0a0a12)); c.addPath(shape); c.fillPath()
    let scale = box.width / 24
    c.saveGState()
    c.translateBy(x: box.minX, y: box.minY)
    c.scaleBy(x: scale, y: scale)
    c.setStrokeColor(color(0xccff00))
    c.setLineWidth(2)
    c.setLineCap(.round)
    c.setLineJoin(.round)
    let flakes: [[CGPoint]] = [
        [CGPoint(x: 10, y: 4), CGPoint(x: 12, y: 5), CGPoint(x: 14, y: 4)],
        [CGPoint(x: 12, y: 2), CGPoint(x: 12, y: 8.5), CGPoint(x: 15, y: 10.22)],
        [CGPoint(x: 17.928, y: 6.268), CGPoint(x: 18.062, y: 8.5), CGPoint(x: 19.928, y: 9.732)],
        [CGPoint(x: 20.66, y: 7), CGPoint(x: 15.031, y: 10.25), CGPoint(x: 15.041, y: 13.708)],
        [CGPoint(x: 19.928, y: 14.268), CGPoint(x: 18.062, y: 15.5), CGPoint(x: 17.928, y: 17.732)],
        [CGPoint(x: 20.66, y: 17), CGPoint(x: 15.031, y: 13.75), CGPoint(x: 12.041, y: 15.488)],
        [CGPoint(x: 14, y: 20), CGPoint(x: 12, y: 19), CGPoint(x: 10, y: 20)],
        [CGPoint(x: 12, y: 22), CGPoint(x: 12, y: 15.5), CGPoint(x: 9, y: 13.78)],
        [CGPoint(x: 6.072, y: 17.732), CGPoint(x: 5.938, y: 15.5), CGPoint(x: 4.072, y: 14.268)],
        [CGPoint(x: 3.34, y: 17), CGPoint(x: 8.969, y: 13.75), CGPoint(x: 8.959, y: 10.292)],
        [CGPoint(x: 4.072, y: 9.732), CGPoint(x: 5.938, y: 8.5), CGPoint(x: 6.072, y: 6.268)],
        [CGPoint(x: 3.34, y: 7), CGPoint(x: 8.969, y: 10.25), CGPoint(x: 11.959, y: 8.512)]
    ]
    for flake in flakes { stroke(flake, in: c) }
    c.restoreGState()
}
let arguments = CommandLine.arguments
if arguments.count != 3 { fatalError("Usage: render-install-art.swift background|icon output-directory") }
let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
switch arguments[1] {
case "background":
    for scale in [1, 2] {
        try render(660, 440, scale: scale, to: output.appendingPathComponent(scale == 1 ? "Snowy.png" : "Snowy@2x.png"), draw: background)
    }
case "icon":
    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
            try render(size, size, scale: scale, to: output.appendingPathComponent(name)) { icon($0, size: CGFloat(size)) }
        }
    }
default: fatalError("Unknown artwork type")
}
