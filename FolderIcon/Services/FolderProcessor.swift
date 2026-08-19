import AppKit
import Darwin
import UniformTypeIdentifiers

enum FolderProcessor {
    static let canvasSize: CGFloat = 512

    // MARK: - Icon generation

    static func createCustomFolder(
        tint: FolderTint,
        symbolName: String,
        symbolSize: CGFloat,
        symbolColor: NSColor,
        style: IconStyle,
        tintOpacity: Double = 0.5,
        isEmoji: Bool = false,
        customImage: NSImage? = nil
    ) -> NSImage? {
        renderImage(size: NSSize(width: canvasSize, height: canvasSize)) { rect in
            let folderIcon = NSWorkspace.shared.icon(for: .folder)
            folderIcon.draw(in: rect)

            // Recolor: take hue & saturation from the tint, keep the
            // original luminance (shading, highlights, volume).
            // Source alpha (opacity) mixes original vs. recolored look.
            applyTint(tint, opacity: tintOpacity, in: rect)

            // The color blend also paints into transparent areas —
            // clip everything back to the folder silhouette.
            folderIcon.draw(
                in: rect, from: .zero, operation: .destinationIn, fraction: 1)

            if let customImage {
                drawCustomImage(
                    customImage, style: style, customColor: symbolColor, in: rect,
                    size: symbolSize)
            } else if isEmoji {
                drawEmoji(symbolName, in: rect, size: symbolSize)
            } else {
                drawSymbol(
                    symbolName, folderColor: tint.referenceColor, customSymbolColor: symbolColor,
                    style: style, in: rect, size: symbolSize)
            }
        }
    }

    /// Draws into an offscreen bitmap and returns the result as an `NSImage`.
    private static func renderImage(size: NSSize, drawing: (NSRect) -> Void) -> NSImage? {
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: max(1, Int(size.width)),
                pixelsHigh: max(1, Int(size.height)),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0)
        else { return nil }
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        drawing(NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    private static func applyTint(_ tint: FolderTint, opacity: Double, in rect: NSRect) {
        switch tint {
        case .solid(let color):
            blendDraw(.color) {
                // Pure CG fill: NSRect.fill()/NSColor.setFill() ignore the
                // CG blend mode and would paint a flat color instead.
                if let cg = NSGraphicsContext.current?.cgContext {
                    let alphaColor = color.withAlphaComponent(CGFloat(opacity))
                    cg.setFillColor(alphaColor.cgColor)
                    cg.fill(CGRect(origin: .zero, size: rect.size))
                }
            }
        case .gradient(let start, let end, let angle):
            drawLinearGradient(
                start: start.withAlphaComponent(CGFloat(opacity)),
                end: end.withAlphaComponent(CGFloat(opacity)),
                angle: angle,
                blendMode: .color,
                in: rect)
        }
    }

    /// Linear gradient over the folder. With `.color` blend mode it
    /// recolors the folder while preserving its luminance (volume).
    /// Angle in degrees: 0 = left-to-right, 90 = bottom-to-top.
    private static func drawLinearGradient(
        start: NSColor, end: NSColor, angle: Double, blendMode: CGBlendMode,
        in rect: NSRect
    ) {
        guard
            let cg = NSGraphicsContext.current?.cgContext,
            let startCG = start.usingColorSpace(.sRGB)?.cgColor,
            let endCG = end.usingColorSpace(.sRGB)?.cgColor,
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let gradient = CGGradient(
                colorsSpace: space, colors: [startCG, endCG] as CFArray, locations: [0, 1])
        else { return }

        let radians = CGFloat(angle) * .pi / 180
        let dx = cos(radians)
        let dy = sin(radians)
        let half = sqrt(rect.width * rect.width + rect.height * rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        cg.saveGState()
        cg.setBlendMode(blendMode)
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: center.x - dx * half, y: center.y - dy * half),
            end: CGPoint(x: center.x + dx * half, y: center.y + dy * half),
            options: [])
        cg.restoreGState()
    }

    private static func fill(sourceAtop color: NSColor, in rect: NSRect) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        cg.setBlendMode(.sourceAtop)
        color.setFill()
        rect.fill()
        cg.restoreGState()
    }

    private static func blendDraw(_ mode: CGBlendMode, drawing: () -> Void) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        cg.setBlendMode(mode)
        drawing()
        cg.restoreGState()
    }

    private static func drawSymbol(
        _ name: String, folderColor: NSColor, customSymbolColor: NSColor, style: IconStyle,
        in rect: NSRect, size: CGFloat
    ) {
        guard !name.isEmpty else { return }

        let finalColor: NSColor
        switch style {
        case .vibrant:
            finalColor = NSColor(white: 0.1, alpha: 0.3)
        case .original:
            finalColor = .black
        case .color:
            finalColor = customSymbolColor
        case .inverted:
            if let rgbFolder = folderColor.usingColorSpace(.sRGB) {
                finalColor = NSColor(
                    red: 1.0 - rgbFolder.redComponent,
                    green: 1.0 - rgbFolder.greenComponent,
                    blue: 1.0 - rgbFolder.blueComponent,
                    alpha: 1.0)
            } else {
                finalColor = .white
            }
        }

        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .bold)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: finalColor))

        guard
            let symbolImage = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
        else { return }

        let x = (rect.width - symbolImage.size.width) / 2
        let y = (rect.height - symbolImage.size.height) / 2 - 40
        let symbolRect = NSRect(origin: CGPoint(x: x, y: y), size: symbolImage.size)

        if style == .vibrant {
            blendDraw(.multiply) {
                symbolImage.draw(in: symbolRect)
            }
        } else {
            symbolImage.draw(in: symbolRect)
        }
    }

    private static func drawEmoji(_ emoji: String, in rect: NSRect, size: CGFloat) {
        guard !emoji.isEmpty else { return }

        let font = NSFont.systemFont(ofSize: size)
        let string = NSAttributedString(string: emoji, attributes: [.font: font])
        let stringSize = string.size()

        let x = (rect.width - stringSize.width) / 2
        let y = (rect.height - stringSize.height) / 2 - 40

        string.draw(in: NSRect(origin: CGPoint(x: x, y: y), size: stringSize))
    }

    private static func drawCustomImage(
        _ image: NSImage, style: IconStyle, customColor: NSColor, in rect: NSRect, size: CGFloat
    ) {
        let targetSize = NSSize(width: size, height: size)
        let x = (rect.width - targetSize.width) / 2
        let y = (rect.height - targetSize.height) / 2 - 40
        let targetRect = NSRect(origin: CGPoint(x: x, y: y), size: targetSize)

        switch style {
        case .color:
            if let tinted = tint(image, with: customColor) {
                tinted.draw(in: targetRect)
            } else {
                image.draw(in: targetRect)
            }
        case .vibrant:
            blendDraw(.multiply) {
                image.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 0.4)
            }
        case .original, .inverted:
            image.draw(in: targetRect)
        }
    }

    private static func tint(_ image: NSImage, with color: NSColor) -> NSImage? {
        renderImage(size: image.size) { rect in
            image.draw(in: rect)
            fill(sourceAtop: color, in: rect)
        }
    }

    // MARK: - Icon management

    @discardableResult
    static func applyIcon(_ image: NSImage, to folderURL: URL) -> Bool {
        NSWorkspace.shared.setIcon(image, forFile: folderURL.path, options: [])
    }

    /// Restores the default folder icon by removing the custom icon
    /// ("Icon\r") file and clearing the Finder custom-icon flag.
    static func resetIcon(for folderURL: URL) throws {
        let iconPath = folderURL.path + "/Icon\r"
        if FileManager.default.fileExists(atPath: iconPath) {
            try FileManager.default.removeItem(atPath: iconPath)
        }
        clearCustomIconFlag(for: folderURL)
    }

    /// Clears the `kHasCustomIcon` (0x0400) Finder flag via getattrlist/setattrlist,
    /// leaving all other flags untouched.
    private static func clearCustomIconFlag(for folderURL: URL) {
        let path = folderURL.path

        var query = attrlist()
        query.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        query.commonattr = attrgroup_t(ATTR_CMN_FLAGS)

        var buffer = FlagsAttribute()
        guard getattrlist(path, &query, &buffer, MemoryLayout<FlagsAttribute>.size, 0) == 0 else {
            return
        }

        let kHasCustomIcon: UInt32 = 0x0400
        let newFlags = buffer.flags & ~kHasCustomIcon
        guard newFlags != buffer.flags else { return }

        var flags = newFlags
        _ = setattrlist(path, &query, &flags, MemoryLayout<UInt32>.size, 0)
    }

    private struct FlagsAttribute {
        var length: UInt32 = 0
        var flags: UInt32 = 0
    }
}
