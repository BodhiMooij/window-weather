import CoreGraphics
import Foundation

/// Original autumn backdrops, drawn in the same flat style as the winter starters.
enum AutumnWallpaper: String, CaseIterable, Sendable {
    case mapleRidge = "maple-ridge"
    case orchardDusk = "orchard-dusk"

    var title: String {
        switch self {
        case .mapleRidge: "Maple Ridge"
        case .orchardDusk: "Orchard Dusk"
        }
    }

    func makeImage(width: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: width * 9 / 16,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.scaleBy(x: CGFloat(width) / 1_600, y: CGFloat(width) / 1_600)
        switch self {
        case .mapleRidge: drawMapleRidge(context, space: space)
        case .orchardDusk: drawOrchardDusk(context, space: space)
        }
        return context.makeImage()
    }

    private func drawMapleRidge(_ context: CGContext, space: CGColorSpace) {
        linearSky(context, space: space, colors: [0x3b2218, 0xb85a2c, 0xf2c27a],
                  start: CGPoint(x: 500, y: 900), end: CGPoint(x: 1_100, y: 280))
        let sun = CGPoint(x: 1_210, y: 548)
        radialGlow(context, space: space, center: sun, radius: 170, rgb: 0xffe3b0, opacity: 0.42)
        context.setFillColor(color(0xfff0d2, opacity: 0.95))
        context.fillEllipse(in: CGRect(x: sun.x - 34, y: sun.y - 34, width: 68, height: 68))

        polygon(context, [(0, 310), (140, 368), (310, 332), (520, 430), (690, 348),
                          (860, 390), (1_040, 300), (1_230, 372), (1_420, 318), (1_600, 360),
                          (1_600, 0), (0, 0)], 0x8a534c)
        polygon(context, [(470, 348), (520, 430), (690, 348), (640, 366), (575, 340), (530, 372)], 0xc4896a)
        polygon(context, [(0, 236), (180, 286), (360, 214), (540, 268), (760, 220),
                          (980, 292), (1_180, 230), (1_380, 270), (1_600, 214),
                          (1_600, 0), (0, 0)], 0x5c4036)

        let hill = CGMutablePath()
        hill.move(to: CGPoint(x: 0, y: 168))
        hill.addQuadCurve(to: CGPoint(x: 820, y: 118), control: CGPoint(x: 380, y: 46))
        hill.addQuadCurve(to: CGPoint(x: 1_600, y: 176), control: CGPoint(x: 1_240, y: 196))
        hill.addLines(between: [CGPoint(x: 1_600, y: 0), .zero])
        hill.closeSubpath()
        context.addPath(hill)
        context.setFillColor(color(0x463228))
        context.fillPath()

        let crowns = [0xe2a23a, 0xd2652a, 0xa33c22, 0x6e6a34, 0xc9843a]
        for index in 0..<14 {
            let x = CGFloat(80 + index * 108)
            let ground = ridgeHeight(at: min(x, 1_560))
            let height = CGFloat(88 + (index * 53) % 70)
            canopy(context, x: x, y: ground - height * 0.16, height: height,
                   fills: [crowns[index % crowns.count], crowns[(index + 2) % crowns.count]])
        }
        for index in 0..<22 {
            let x = CGFloat((index * 71 + 40) % 1_560)
            let y = CGFloat(190 + (index * 43) % 150)
            leaf(context, x: x, y: y, rgb: index.isMultiple(of: 3) ? 0xc45a28 : 0xe0a04a, size: index.isMultiple(of: 5) ? 7 : 4)
        }
    }

    private func drawOrchardDusk(_ context: CGContext, space: CGColorSpace) {
        linearSky(context, space: space, colors: [0x241c3c, 0x6a3d58, 0xe39a78],
                  start: CGPoint(x: 700, y: 900), end: CGPoint(x: 900, y: 260))
        let moon = CGPoint(x: 300, y: 640)
        radialGlow(context, space: space, center: moon, radius: 110, rgb: 0xf3dcc8, opacity: 0.28)
        context.setFillColor(color(0xf6e6d8, opacity: 0.92))
        context.fillEllipse(in: CGRect(x: moon.x - 22, y: moon.y - 22, width: 44, height: 44))
        context.setFillColor(color(0x6a3d58))
        context.fillEllipse(in: CGRect(x: moon.x - 8, y: moon.y - 6, width: 28, height: 28))

        polygon(context, [(0, 300), (1_600, 268), (1_600, 0), (0, 0)], 0x4e3b4a)
        for index in 0..<28 {
            let x = CGFloat(index * 58 + 12)
            canopy(context, x: x, y: 250, height: 46, fills: [0x5c4638, 0x6a5344])
        }

        let field = CGMutablePath()
        field.move(to: CGPoint(x: 0, y: 248))
        field.addQuadCurve(to: CGPoint(x: 1_600, y: 220), control: CGPoint(x: 780, y: 188))
        field.addLines(between: [CGPoint(x: 1_600, y: 0), .zero])
        field.closeSubpath()
        context.addPath(field)
        context.setFillColor(color(0x6a4a32))
        context.fillPath()

        let path = CGMutablePath()
        path.move(to: CGPoint(x: 760, y: 0))
        path.addQuadCurve(to: CGPoint(x: 690, y: 230), control: CGPoint(x: 820, y: 120))
        path.addLine(to: CGPoint(x: 760, y: 236))
        path.addQuadCurve(to: CGPoint(x: 860, y: 0), control: CGPoint(x: 900, y: 110))
        path.closeSubpath()
        context.addPath(path)
        context.setFillColor(color(0x7c5a3c))
        context.fillPath()

        for row in 0..<3 {
            let count = 8 - row
            let height = CGFloat(78 + row * 28)
            let baseline = CGFloat(168 - row * 46)
            for index in 0..<count {
                let x = CGFloat(90 + row * 36) + CGFloat(index) * (170 - CGFloat(row) * 12)
                guard x < 1_090 else { continue }
                canopy(context, x: x, y: baseline, height: height, fills: [0xc46a32, 0x8d4a28, 0x6e6a34])
            }
        }

        context.setFillColor(color(0x5c4034))
        context.fill(CGRect(x: 1_180, y: 118, width: 168, height: 86))
        polygon(context, [(1_158, 200), (1_264, 262), (1_370, 200)], 0x7a342c)
        context.setFillColor(color(0xc47a3a))
        context.fill(CGRect(x: 1_242, y: 128, width: 36, height: 52))
        context.fill(CGRect(x: 1_198, y: 168, width: 22, height: 16))
        context.fill(CGRect(x: 1_308, y: 168, width: 22, height: 16))

        for index in 0..<34 {
            let x = CGFloat((index * 97 + 20) % 1_540)
            let y = CGFloat(18 + (index * 29) % 150)
            leaf(context, x: x, y: y, rgb: index.isMultiple(of: 2) ? 0xd2652a : 0xe2a23a, size: 5)
        }
    }

    private func ridgeHeight(at x: CGFloat) -> CGFloat {
        if x <= 820 {
            return quadY(at: x, from: CGPoint(x: 0, y: 168), control: CGPoint(x: 380, y: 46), to: CGPoint(x: 820, y: 118))
        }
        return quadY(at: x, from: CGPoint(x: 820, y: 118), control: CGPoint(x: 1_240, y: 196), to: CGPoint(x: 1_600, y: 176))
    }

    private func quadY(at x: CGFloat, from start: CGPoint, control: CGPoint, to end: CGPoint) -> CGFloat {
        let a = start.x - 2 * control.x + end.x
        let b = 2 * (control.x - start.x)
        let c = start.x - x
        let t: CGFloat
        if abs(a) < 0.001 {
            t = abs(b) < 0.001 ? 0 : max(0, min(1, -c / b))
        } else {
            let root = (-b + sqrt(max(0, b * b - 4 * a * c))) / (2 * a)
            t = max(0, min(1, root))
        }
        let u = 1 - t
        return u * u * start.y + 2 * u * t * control.y + t * t * end.y
    }

    private func canopy(_ context: CGContext, x: CGFloat, y: CGFloat, height: CGFloat, fills: [Int]) {
        context.setFillColor(color(0x3a2a22))
        let trunk = height * 0.07
        context.fill(CGRect(x: x - trunk / 2, y: y, width: trunk, height: height * 0.38))
        let crown = y + height * 0.26
        let blobs: [(CGFloat, CGFloat, CGFloat)] = [(0, 0.2, 0.36), (-0.2, 0.1, 0.26), (0.18, 0.08, 0.24), (0.02, 0.36, 0.22)]
        for (index, blob) in blobs.enumerated() {
            let width = height * blob.2
            context.setFillColor(color(fills[index % fills.count]))
            context.fillEllipse(in: CGRect(x: x + height * blob.0 - width / 2, y: crown + height * blob.1,
                                           width: width, height: width * 0.78))
        }
    }

    private func leaf(_ context: CGContext, x: CGFloat, y: CGFloat, rgb: Int, size: CGFloat) {
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.rotate(by: x * 0.01)
        context.setFillColor(color(rgb, opacity: 0.9))
        context.fillEllipse(in: CGRect(x: -size, y: -size * 0.35, width: size * 2, height: size))
        context.restoreGState()
    }

    private func linearSky(_ context: CGContext, space: CGColorSpace, colors: [Int], start: CGPoint, end: CGPoint) {
        guard let gradient = CGGradient(colorsSpace: space, colors: colors.map { color($0) } as CFArray,
                                        locations: [0, 0.62, 1]) else { return }
        context.drawLinearGradient(gradient, start: start, end: end,
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private func radialGlow(_ context: CGContext, space: CGColorSpace, center: CGPoint, radius: CGFloat, rgb: Int, opacity: CGFloat) {
        guard let glow = CGGradient(colorsSpace: space,
                                    colors: [color(rgb, opacity: opacity), color(rgb, opacity: 0)] as CFArray,
                                    locations: [0, 1]) else { return }
        context.drawRadialGradient(glow, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: radius, options: [])
    }

    private func polygon(_ context: CGContext, _ points: [(CGFloat, CGFloat)], _ fill: Int) {
        let path = CGMutablePath()
        path.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
        path.closeSubpath()
        context.addPath(path)
        context.setFillColor(color(fill))
        context.fillPath()
    }

    private func color(_ rgb: Int, opacity: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                green: CGFloat((rgb >> 8) & 255) / 255,
                blue: CGFloat(rgb & 255) / 255, alpha: opacity)
    }
}
