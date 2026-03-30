import AppKit

let width = 1600
let height = 900
let outputDirectory = "/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Design/tasker-paywall-candidates"

func cgColor(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
}

func fillRounded(_ context: CGContext, _ rect: CGRect, radius: CGFloat, fill: CGColor, stroke: CGColor? = nil, lineWidth: CGFloat = 0) {
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

func glow(_ context: CGContext, center: CGPoint, radius: CGFloat, color: CGColor) {
    let g = gradient([color, color.copy(alpha: 0) ?? color], [0, 1])
    context.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsAfterEndLocation])
}

func circle(_ context: CGContext, center: CGPoint, radius: CGFloat, fill: CGColor) {
    context.setFillColor(fill)
    context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

func ring(_ context: CGContext, center: CGPoint, radius: CGFloat, lineWidth: CGFloat, stroke: CGColor) {
    context.setStrokeColor(stroke)
    context.setLineWidth(lineWidth)
    context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

func strokePath(_ context: CGContext, color: CGColor, lineWidth: CGFloat, lineCap: CGLineCap = .round, build: (CGMutablePath) -> Void) {
    let path = CGMutablePath()
    build(path)
    context.addPath(path)
    context.setStrokeColor(color)
    context.setLineWidth(lineWidth)
    context.setLineCap(lineCap)
    context.strokePath()
}

func profileCard(_ context: CGContext, rect: CGRect, rotation: CGFloat = 0, dark: Bool = false) {
    context.saveGState()
    let transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
        .rotated(by: rotation * .pi / 180)
        .translatedBy(x: -rect.midX, y: -rect.midY)
    context.concatenate(transform)
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 34, color: cgColor(79, 70, 229, 0.22))
    fillRounded(
        context,
        rect,
        radius: 34,
        fill: dark ? cgColor(72, 56, 212, 0.96) : cgColor(255, 255, 255, 0.98),
        stroke: dark ? cgColor(99, 102, 241, 0.9) : cgColor(199, 210, 254, 0.85),
        lineWidth: 2
    )
    context.setShadow(offset: .zero, blur: 0, color: nil)

    circle(context, center: CGPoint(x: rect.minX + 70, y: rect.maxY - 74), radius: 28, fill: dark ? cgColor(255, 255, 255, 0.2) : cgColor(79, 70, 229))
    circle(context, center: CGPoint(x: rect.minX + 70, y: rect.maxY - 68), radius: 9, fill: cgColor(255, 255, 255))
    fillRounded(context, CGRect(x: rect.minX + 56, y: rect.maxY - 104, width: 28, height: 18), radius: 9, fill: cgColor(255, 255, 255))

    fillRounded(context, CGRect(x: rect.minX + 118, y: rect.maxY - 84, width: 200, height: 14), radius: 7, fill: dark ? cgColor(255, 255, 255, 0.9) : cgColor(17, 24, 39, 0.84))
    fillRounded(context, CGRect(x: rect.minX + 118, y: rect.maxY - 114, width: 132, height: 10), radius: 5, fill: dark ? cgColor(255, 255, 255, 0.36) : cgColor(107, 114, 128, 0.45))
    fillRounded(context, CGRect(x: rect.minX + 44, y: rect.minY + 56, width: rect.width - 88, height: 98), radius: 24, fill: dark ? cgColor(255, 255, 255, 0.1) : cgColor(246, 244, 255))
    fillRounded(context, CGRect(x: rect.minX + 70, y: rect.minY + 90, width: rect.width - 140, height: 12), radius: 6, fill: cgColor(227, 221, 255, dark ? 0.9 : 1))
    fillRounded(context, CGRect(x: rect.minX + 70, y: rect.minY + 64, width: rect.width - 210, height: 12), radius: 6, fill: cgColor(191, 227, 255, dark ? 0.9 : 1))
    context.restoreGState()
}

func render(_ filename: String, draw: (CGContext, CGRect) -> Void) throws -> String {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else { fatalError("Missing context") }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let canvas = CGRect(x: 0, y: 0, width: width, height: height)
    context.clear(canvas)
    context.drawLinearGradient(
        gradient([cgColor(249, 248, 255), cgColor(245, 249, 255), cgColor(241, 247, 255)], [0, 0.55, 1]),
        start: CGPoint(x: 0, y: height),
        end: CGPoint(x: width, y: 0),
        options: []
    )
    draw(context, canvas)
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else { fatalError("Failed to encode") }

    let path = "\(outputDirectory)/\(filename)"
    try png.write(to: URL(fileURLWithPath: path))
    return path
}

let one = try render("candidate-4-signal-burst.png") { context, _ in
    glow(context, center: CGPoint(x: 300, y: 700), radius: 320, color: cgColor(124, 92, 255, 0.26))
    glow(context, center: CGPoint(x: 1210, y: 260), radius: 260, color: cgColor(14, 165, 233, 0.22))

    fillRounded(context, CGRect(x: 160, y: 170, width: 1280, height: 560), radius: 64, fill: cgColor(255, 255, 255, 0.44), stroke: cgColor(199, 210, 254, 0.58), lineWidth: 2)

    profileCard(context, rect: CGRect(x: 250, y: 250, width: 520, height: 320), rotation: -6, dark: true)

    strokePath(context, color: cgColor(255, 255, 255, 0.38), lineWidth: 28) { path in
        path.move(to: CGPoint(x: 730, y: 430))
        path.addCurve(to: CGPoint(x: 1210, y: 470), control1: CGPoint(x: 860, y: 610), control2: CGPoint(x: 1070, y: 610))
    }
    strokePath(context, color: cgColor(14, 165, 233, 0.78), lineWidth: 18) { path in
        path.move(to: CGPoint(x: 726, y: 428))
        path.addCurve(to: CGPoint(x: 1210, y: 470), control1: CGPoint(x: 860, y: 610), control2: CGPoint(x: 1070, y: 610))
    }
    strokePath(context, color: cgColor(124, 92, 255, 0.9), lineWidth: 10) { path in
        path.move(to: CGPoint(x: 734, y: 430))
        path.addCurve(to: CGPoint(x: 1210, y: 470), control1: CGPoint(x: 860, y: 590), control2: CGPoint(x: 1070, y: 590))
    }

    let target = CGPoint(x: 1240, y: 472)
    ring(context, center: target, radius: 132, lineWidth: 30, stroke: cgColor(14, 165, 233, 0.16))
    ring(context, center: target, radius: 92, lineWidth: 16, stroke: cgColor(255, 255, 255, 0.7))
    ring(context, center: target, radius: 64, lineWidth: 12, stroke: cgColor(124, 92, 255, 0.46))
    ring(context, center: target, radius: 30, lineWidth: 8, stroke: cgColor(79, 70, 229, 0.9))
    circle(context, center: target, radius: 14, fill: cgColor(79, 70, 229))

    for point in [CGPoint(x: 1080, y: 620), CGPoint(x: 1150, y: 330), CGPoint(x: 940, y: 290), CGPoint(x: 1290, y: 630)] {
        strokePath(context, color: cgColor(14, 165, 233, 0.7), lineWidth: 4, lineCap: .round) { path in
            path.move(to: CGPoint(x: point.x - 12, y: point.y))
            path.addLine(to: CGPoint(x: point.x + 12, y: point.y))
            path.move(to: CGPoint(x: point.x, y: point.y - 12))
            path.addLine(to: CGPoint(x: point.x, y: point.y + 12))
        }
    }
}

let two = try render("candidate-5-spotlight-stage.png") { context, _ in
    glow(context, center: CGPoint(x: 360, y: 680), radius: 260, color: cgColor(79, 70, 229, 0.2))
    glow(context, center: CGPoint(x: 1110, y: 270), radius: 300, color: cgColor(14, 165, 233, 0.18))

    fillRounded(context, CGRect(x: 170, y: 180, width: 1260, height: 540), radius: 64, fill: cgColor(255, 255, 255, 0.35), stroke: cgColor(199, 210, 254, 0.54), lineWidth: 2)

    let beam = CGMutablePath()
    beam.move(to: CGPoint(x: 510, y: 760))
    beam.addLine(to: CGPoint(x: 1110, y: 650))
    beam.addLine(to: CGPoint(x: 920, y: 280))
    beam.addLine(to: CGPoint(x: 340, y: 420))
    beam.closeSubpath()
    context.addPath(beam)
    context.setFillColor(cgColor(255, 255, 255, 0.42))
    context.fillPath()

    profileCard(context, rect: CGRect(x: 390, y: 300, width: 430, height: 260), rotation: 0, dark: false)

    strokePath(context, color: cgColor(124, 92, 255, 0.7), lineWidth: 14) { path in
        path.move(to: CGPoint(x: 820, y: 430))
        path.addCurve(to: CGPoint(x: 1100, y: 430), control1: CGPoint(x: 900, y: 520), control2: CGPoint(x: 1020, y: 520))
    }

    let beacon = CGPoint(x: 1160, y: 430)
    ring(context, center: beacon, radius: 118, lineWidth: 24, stroke: cgColor(14, 165, 233, 0.18))
    ring(context, center: beacon, radius: 80, lineWidth: 14, stroke: cgColor(255, 255, 255, 0.7))
    ring(context, center: beacon, radius: 48, lineWidth: 10, stroke: cgColor(79, 70, 229, 0.42))
    circle(context, center: beacon, radius: 18, fill: cgColor(79, 70, 229))

    let pin = CGMutablePath()
    pin.move(to: CGPoint(x: 1260, y: 600))
    pin.addCurve(to: CGPoint(x: 1224, y: 528), control1: CGPoint(x: 1294, y: 584), control2: CGPoint(x: 1286, y: 544))
    pin.addCurve(to: CGPoint(x: 1260, y: 460), control1: CGPoint(x: 1162, y: 508), control2: CGPoint(x: 1180, y: 460))
    pin.addCurve(to: CGPoint(x: 1296, y: 528), control1: CGPoint(x: 1340, y: 460), control2: CGPoint(x: 1358, y: 508))
    pin.addCurve(to: CGPoint(x: 1260, y: 600), control1: CGPoint(x: 1238, y: 544), control2: CGPoint(x: 1230, y: 584))
    context.addPath(pin)
    context.setFillColor(cgColor(14, 165, 233))
    context.fillPath()
    circle(context, center: CGPoint(x: 1260, y: 512), radius: 14, fill: cgColor(255, 255, 255))
}

let three = try render("candidate-6-orbit-lock.png") { context, _ in
    glow(context, center: CGPoint(x: 260, y: 660), radius: 260, color: cgColor(124, 92, 255, 0.24))
    glow(context, center: CGPoint(x: 1280, y: 340), radius: 260, color: cgColor(14, 165, 233, 0.2))

    fillRounded(context, CGRect(x: 180, y: 180, width: 1240, height: 540), radius: 72, fill: cgColor(255, 255, 255, 0.4), stroke: cgColor(199, 210, 254, 0.54), lineWidth: 2)

    profileCard(context, rect: CGRect(x: 240, y: 290, width: 470, height: 280), rotation: -8, dark: false)
    profileCard(context, rect: CGRect(x: 390, y: 240, width: 360, height: 220), rotation: 6, dark: true)

    let orbitCenter = CGPoint(x: 1180, y: 430)
    ring(context, center: orbitCenter, radius: 170, lineWidth: 36, stroke: cgColor(14, 165, 233, 0.14))
    ring(context, center: orbitCenter, radius: 118, lineWidth: 16, stroke: cgColor(124, 92, 255, 0.3))
    ring(context, center: orbitCenter, radius: 74, lineWidth: 12, stroke: cgColor(255, 255, 255, 0.75))
    ring(context, center: orbitCenter, radius: 42, lineWidth: 10, stroke: cgColor(79, 70, 229, 0.82))
    circle(context, center: orbitCenter, radius: 16, fill: cgColor(79, 70, 229))

    strokePath(context, color: cgColor(255, 255, 255, 0.4), lineWidth: 26) { path in
        path.move(to: CGPoint(x: 690, y: 420))
        path.addCurve(to: CGPoint(x: 1080, y: 432), control1: CGPoint(x: 860, y: 600), control2: CGPoint(x: 980, y: 600))
    }
    strokePath(context, color: cgColor(124, 92, 255, 0.82), lineWidth: 12) { path in
        path.move(to: CGPoint(x: 690, y: 420))
        path.addCurve(to: CGPoint(x: 1080, y: 432), control1: CGPoint(x: 860, y: 600), control2: CGPoint(x: 980, y: 600))
    }

    for point in [CGPoint(x: 880, y: 260), CGPoint(x: 1010, y: 650), CGPoint(x: 1330, y: 610)] {
        circle(context, center: point, radius: 7, fill: cgColor(14, 165, 233, 0.8))
        ring(context, center: point, radius: 18, lineWidth: 3, stroke: cgColor(14, 165, 233, 0.26))
    }
}

print(one)
print(two)
print(three)
