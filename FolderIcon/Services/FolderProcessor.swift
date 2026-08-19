import AppKit
import Darwin
import UniformTypeIdentifiers

enum FolderProcessor {
    static let canvasSize: CGFloat = 512

    /// Shared Core Image context. Creating a `CIContext` is expensive, and
    /// it is thread-safe, so one instance is reused for every render.
    private static let ciContext = CIContext()

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

            // Recolor by multiplying the chosen color (or gradient) by the
            // folder's luminance map: the hue/saturation is EXACTLY the picked
            // color everywhere, while Apple's shading/gloss survives as
            // brightness variation. No blue from the original bleeds through.
            drawRecoloredFolder(tint: tint, in: rect)

            // Partial opacity blends the original (blue) folder back in.
            if tintOpacity < 1 {
                folderIcon.draw(
                    in: rect, from: .zero, operation: .sourceOver,
                    fraction: CGFloat(1 - tintOpacity))
            }

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

    /// Draws the folder silhouette filled with the exact chosen color/gradient,
    /// then multiplies the folder's luminance map over it so the shading,
    /// gloss and volume of the system folder are preserved.
    private static func drawRecoloredFolder(tint: FolderTint, in rect: NSRect) {
        let folderIcon = NSWorkspace.shared.icon(for: .folder)

        guard
            let base = renderImage(size: rect.size, drawing: { folderIcon.draw(in: $0) }),
            let baseCG = base.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let gray = CGContext(
                data: nil,
                width: baseCG.width, height: baseCG.height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return }

        gray.draw(
            baseCG, in: CGRect(x: 0, y: 0, width: baseCG.width, height: baseCG.height))
        guard let grayCG = gray.makeImage() else { return }

        switch tint {
        case .solid(let color):
            color.withAlphaComponent(1).setFill()
            rect.fill()
        case .gradient(let start, let end, let angle):
            drawLinearGradient(
                start: start, end: end, angle: angle, blendMode: .normal, in: rect)
        }

        // Clip to the folder silhouette without the baked drop shadow
        // (alpha >= 0.7 keeps the body, cuts the dark halo outside it).
        if let mask = silhouetteMask(from: baseCG) {
            NSImage(cgImage: mask, size: rect.size).draw(
                in: rect, from: .zero, operation: .destinationIn, fraction: 1)
        }

        // Multiply the shading on top: exact color, Apple's volume preserved.
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        cg.setBlendMode(.multiply)
        cg.draw(grayCG, in: CGRect(origin: .zero, size: rect.size))
        cg.restoreGState()
    }

    /// Hard silhouette of the folder body: alpha thresholded at 0.7.
    /// The system folder artwork has a dark drop shadow baked into the alpha;
    /// thresholding removes it so the recolored folder has clean edges.
    private static func silhouetteMask(from cgImage: CGImage) -> CGImage? {
        guard
            let ctx = CGContext(
                data: nil,
                width: cgImage.width, height: cgImage.height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
        else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        guard let alpha = ctx.makeImage() else { return nil }

        let ci = CIImage(cgImage: alpha)
        let filter = CIFilter(
            name: "CIColorThreshold",
            parameters: [kCIInputImageKey: ci, "inputThreshold": 0.7])
        guard let output = filter?.outputImage else { return nil }
        return ciContext.createCGImage(output, from: output.extent)
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
        // Aspect-fit the image into the square slot so non-square logos keep
        // their proportions instead of being stretched.
        let aspect = image.size.height > 0 ? image.size.width / image.size.height : 1
        let fitSize = aspect >= 1
            ? NSSize(width: size, height: size / aspect)
            : NSSize(width: size * aspect, height: size)
        let targetRect = NSRect(
            x: rect.midX - fitSize.width / 2,
            y: rect.midY - fitSize.height / 2 - 40,
            width: fitSize.width, height: fitSize.height)

        switch style {
        case .color:
            // Render the tint at most 2x the final on-canvas size: the result
            // is drawn at `fitSize`, so a full-resolution intermediate bitmap
            // (e.g. a 4000px logo) is pure waste.
            let maxDimension = max(fitSize.width, fitSize.height) * 2
            if let tinted = tint(image, with: customColor, maxDimension: maxDimension) {
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

    private static func tint(
        _ image: NSImage, with color: NSColor, maxDimension: CGFloat
    ) -> NSImage? {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height, 1))
        let renderSize = NSSize(
            width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        return renderImage(size: renderSize) { rect in
            image.draw(in: rect)
            fill(sourceAtop: color, in: rect)
        }
    }

    // MARK: - Icon management

    @discardableResult
    static func applyIcon(_ image: NSImage, to folderURL: URL) -> Bool {
        NSWorkspace.shared.setIcon(image, forFile: folderURL.path, options: [])
    }

    enum ResetError: LocalizedError {
        case cannotReadFlags
        case cannotClearFlag

        var errorDescription: String? {
            switch self {
            case .cannotReadFlags:
                return "Could not read the folder flags"
            case .cannotClearFlag:
                return "Could not clear the custom-icon flag"
            }
        }
    }

    /// Restores the default folder icon by removing the custom icon
    /// ("Icon\r") file and clearing the Finder custom-icon flag.
    /// Throws if the flag cannot be read or cleared, so callers report the
    /// failure instead of assuming the icon was restored.
    static func resetIcon(for folderURL: URL) throws {
        let iconPath = folderURL.path + "/Icon\r"
        if FileManager.default.fileExists(atPath: iconPath) {
            try FileManager.default.removeItem(atPath: iconPath)
        }
        try clearCustomIconFlag(for: folderURL)
    }

    /// Clears the `kHasCustomIcon` (0x0400) Finder flag via getattrlist/setattrlist,
    /// leaving all other flags untouched. No-ops when the flag is already
    /// cleared; throws if the underlying syscalls fail.
    private static func clearCustomIconFlag(for folderURL: URL) throws {
        let path = folderURL.path

        var query = attrlist()
        query.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        query.commonattr = attrgroup_t(ATTR_CMN_FLAGS)

        var buffer = FlagsAttribute()
        guard getattrlist(path, &query, &buffer, MemoryLayout<FlagsAttribute>.size, 0) == 0 else {
            throw ResetError.cannotReadFlags
        }

        let kHasCustomIcon: UInt32 = 0x0400
        let newFlags = buffer.flags & ~kHasCustomIcon
        guard newFlags != buffer.flags else { return }

        var flags = newFlags
        guard setattrlist(path, &query, &flags, MemoryLayout<UInt32>.size, 0) == 0 else {
            throw ResetError.cannotClearFlag
        }
    }

    private struct FlagsAttribute {
        var length: UInt32 = 0
        var flags: UInt32 = 0
    }
}
