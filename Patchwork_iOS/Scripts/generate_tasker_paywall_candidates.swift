import AppKit

let width = 1600
let height = 900
let outputDirectory = "/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Design/tasker-paywall-candidates"

typealias DrawBlock = (_ context: CGContext, _ canvas: CGRect) -> Void

func cgColor(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func makeGradient(colors: [CGColor], locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
}

func drawRoundedRect(
    _ context: CGContext,
    rect: CGRect,
    radius: CGFloat,
    fill: CGColor,
    stroke: CGColor? = nil,
    lineWidth: CGFloat = 0
) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.setFillColor(fill)
    context.fillPath()

    if let stroke {
        context.addPath(path)
        context.setStrokeColor(stroke)
        context.setLineWidth(lineWidth)
        context.strokePath()
    }
}

func drawGlow(_ context: CGContext, center: CGPoint, radius: CGFloat, color: CGColor) {
    let gradient = makeGradient(colors: [color, color.copy(alpha: 0) ?? color], locations: [0, 1])
    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
}

func fillCircle(_ context: CGContext, center: CGPoint, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

func drawRing(_ context: CGContext, center: CGPoint, radius: CGFloat, lineWidth: CGFloat, color: CGColor) {
    context.setStrokeColor(color)
    context.setLineWidth(lineWidth)
    context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

func drawPath(_ context: CGContext, color: CGColor, lineWidth: CGFloat, lineCap: CGLineCap = .round, build: (CGMutablePath) -> Void) {
    let path = CGMutablePath()
    build(path)
    context.addPath(path)
    context.setStrokeColor(color)
    context.setLineWidth(lineWidth)
    context.setLineCap(lineCap)
    context.strokePath()
}

func drawProfileCard(_ context: CGContext, origin: CGPoint, size: CGSize, rotationDegrees: CGFloat = 0) {
    let rect = CGRect(origin: origin, size: size)
    let transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
        .rotated(by: rotationDegrees * .pi / 180)
        .translatedBy(x: -rect.midX, y: -rect.midY)
    let path = CGPath(roundedRect: rect, cornerWidth: 34, cornerHeight: 34, transform: nil)

    context.saveGState()
    context.concatenate(transform)
    context.addPath(path)
    context.setFillColor(cgColor(255, 255, 255, 0.96))
    context.setShadow(offset: CGSize(width: 0, height: -20), blur: 36, color: cgColor(79, 70, 229, 0.14))
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.addPath(path)
    context.setStrokeColor(cgColor(199, 210, 254, 0.7))
    context.setLineWidth(2)
    context.strokePath()

    fillCircle(context, center: CGPoint(x: rect.minX + 86, y: rect.maxY - 86), radius: 28, color: cgColor(79, 70, 229))
    fillCircle(context, center: CGPoint(x: rect.minX + 86, y: rect.maxY - 80), radius: 9, color: cgColor(255, 255, 255))
    drawRoundedRect(context, rect: CGRect(x: rect.minX + 72, y: rect.maxY - 116, width: 28, height: 18), radius: 9, fill: cgColor(255, 255, 255))

    drawRoundedRect(context, rect: CGRect(x: rect.minX + 136, y: rect.maxY - 92, width: 180, height: 14), radius: 7, fill: cgColor(17, 24, 39, 0.86))
    drawRoundedRect(context, rect: CGRect(x: rect.minX + 136, y: rect.maxY - 124, width: 112, height: 10), radius: 5, fill: cgColor(107, 114, 128, 0.45))
    drawRoundedRect(context, rect: CGRect(x: rect.minX + 54, y: rect.minY + 60, width: size.width - 108, height: 104), radius: 26, fill: cgColor(248, 248, 255))
    drawRoundedRect(context, rect: CGRect(x: rect.minX + 76, y: rect.minY + 92, width: size.width - 152, height: 12), radius: 6, fill: cgColor(227, 221, 255))
    drawRoundedRect(context, rect: CGRect(x: rect.minX + 76, y: rect.minY + 66, width: size.width - 194, height: 12), radius: 6, fill: cgColor(191, 227, 255))
    context.restoreGState()
}

func render(filename: String, draw: DrawBlock) throws -> String {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("Missing graphics context")
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let canvas = CGRect(x: 0, y: 0, width: width, height: height)
    context.clear(canvas)

    let baseGradient = makeGradient(
        colors: [
            cgColor(250, 248, 255),
            cgColor(248, 251, 255),
            cgColor(241, 247, 255)
        ],
        locations: [0, 0.55, 1]
    )
    context.drawLinearGradient(baseGradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])

    draw(context, canvas)
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Failed to encode image")
    }

    let path = "\(outputDirectory)/\(filename)"
    try png.write(to: URL(fileURLWithPath: path))
    return path
}

let editorialSpotlight = try render(filename: "candidate-1-editorial-spotlight.png") { context, _ in
    drawGlow(context, center: CGPoint(x: 320, y: 680), radius: 280, color: cgColor(124, 92, 255, 0.18))
    drawGlow(context, center: CGPoint(x: 1240, y: 260), radius: 240, color: cgColor(14, 165, 233, 0.15))

    drawRoundedRect(
        context,
        rect: CGRect(x: 180, y: 180, width: 1240, height: 540),
        radius: 60,
        fill: cgColor(255, 255, 255, 0.58),
        stroke: cgColor(199, 210, 254, 0.55),
        lineWidth: 2
    )

    drawProfileCard(context, origin: CGPoint(x: 290, y: 280), size: CGSize(width: 500, height: 320), rotationDegrees: -5)

    drawPath(context, color: cgColor(124, 92, 255, 0.34), lineWidth: 18) { path in
        path.move(to: CGPoint(x: 770, y: 430))
        path.addCurve(to: CGPoint(x: 1140, y: 470), control1: CGPoint(x: 900, y: 540), control2: CGPoint(x: 1020, y: 570))
    }

    let target = CGPoint(x: 1210, y: 470)
    drawRing(context, center: target, radius: 96, lineWidth: 24, color: cgColor(14, 165, 233, 0.12))
    drawRing(context, center: target, radius: 62, lineWidth: 14, color: cgColor(79, 70, 229, 0.18))
    drawRing(context, center: target, radius: 34, lineWidth: 8, color: cgColor(79, 70, 229, 0.42))
    fillCircle(context, center: target, radius: 12, color: cgColor(79, 70, 229))
}

let mapPulse = try render(filename: "candidate-2-map-pulse.png") { context, _ in
    drawGlow(context, center: CGPoint(x: 500, y: 540), radius: 240, color: cgColor(79, 70, 229, 0.16))
    drawGlow(context, center: CGPoint(x: 1100, y: 300), radius: 260, color: cgColor(14, 165, 233, 0.16))

    drawRoundedRect(
        context,
        rect: CGRect(x: 180, y: 180, width: 1240, height: 540),
        radius: 60,
        fill: cgColor(255, 255, 255, 0.42),
        stroke: cgColor(199, 210, 254, 0.48),
        lineWidth: 2
    )

    for x in stride(from: 240.0, through: 1340.0, by: 90.0) {
        drawPath(context, color: cgColor(79, 70, 229, 0.05), lineWidth: 2, lineCap: .butt) { path in
            path.move(to: CGPoint(x: x, y: 220))
            path.addLine(to: CGPoint(x: x, y: 680))
        }
    }

    for y in stride(from: 240.0, through: 680.0, by: 90.0) {
        drawPath(context, color: cgColor(79, 70, 229, 0.05), lineWidth: 2, lineCap: .butt) { path in
            path.move(to: CGPoint(x: 220, y: y))
            path.addLine(to: CGPoint(x: 1380, y: y))
        }
    }

    drawProfileCard(context, origin: CGPoint(x: 270, y: 250), size: CGSize(width: 420, height: 280))

    drawPath(context, color: cgColor(14, 165, 233, 0.36), lineWidth: 20) { path in
        path.move(to: CGPoint(x: 680, y: 360))
        path.addCurve(to: CGPoint(x: 1080, y: 520), control1: CGPoint(x: 820, y: 500), control2: CGPoint(x: 930, y: 560))
        path.addCurve(to: CGPoint(x: 1250, y: 430), control1: CGPoint(x: 1160, y: 500), control2: CGPoint(x: 1220, y: 470))
    }

    let pulse = CGPoint(x: 1250, y: 430)
    drawRing(context, center: pulse, radius: 110, lineWidth: 20, color: cgColor(14, 165, 233, 0.18))
    drawRing(context, center: pulse, radius: 70, lineWidth: 12, color: cgColor(79, 70, 229, 0.2))
    fillCircle(context, center: pulse, radius: 16, color: cgColor(79, 70, 229))
}

let glassLayers = try render(filename: "candidate-3-glass-layers.png") { context, _ in
    drawGlow(context, center: CGPoint(x: 390, y: 690), radius: 260, color: cgColor(124, 92, 255, 0.18))
    drawGlow(context, center: CGPoint(x: 1220, y: 290), radius: 220, color: cgColor(14, 165, 233, 0.14))

    drawRoundedRect(
        context,
        rect: CGRect(x: 210, y: 220, width: 1180, height: 480),
        radius: 72,
        fill: cgColor(255, 255, 255, 0.5),
        stroke: cgColor(199, 210, 254, 0.54),
        lineWidth: 2
    )

    drawRoundedRect(
        context,
        rect: CGRect(x: 330, y: 310, width: 520, height: 250),
        radius: 44,
        fill: cgColor(255, 255, 255, 0.92),
        stroke: cgColor(199, 210, 254, 0.72),
        lineWidth: 2
    )

    drawRoundedRect(
        context,
        rect: CGRect(x: 690, y: 360, width: 340, height: 170),
        radius: 36,
        fill: cgColor(245, 248, 255, 0.8),
        stroke: cgColor(191, 227, 255, 0.74),
        lineWidth: 2
    )

    drawProfileCard(context, origin: CGPoint(x: 370, y: 340), size: CGSize(width: 440, height: 190))

    let locator = CGPoint(x: 1080, y: 445)
    drawRing(context, center: locator, radius: 88, lineWidth: 20, color: cgColor(79, 70, 229, 0.12))
    drawRing(context, center: locator, radius: 52, lineWidth: 10, color: cgColor(14, 165, 233, 0.24))
    fillCircle(context, center: locator, radius: 14, color: cgColor(79, 70, 229))

    drawPath(context, color: cgColor(124, 92, 255, 0.38), lineWidth: 16) { path in
        path.move(to: CGPoint(x: 790, y: 430))
        path.addCurve(to: CGPoint(x: 1012, y: 444), control1: CGPoint(x: 850, y: 490), control2: CGPoint(x: 930, y: 490))
    }
}

print(editorialSpotlight)
print(mapPulse)
print(glassLayers)
