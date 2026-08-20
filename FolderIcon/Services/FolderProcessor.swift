import AppKit
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
        tintOpacity: Double = 1.0,
        iconOffset: CGSize = .zero,
        isEmoji: Bool = false,
        customImage: NSImage? = nil
    ) -> NSImage? {
        renderImage(size: NSSize(width: canvasSize, height: canvasSize)) { rect in
            // Render the recolored folder as an isolated layer, then apply
            // opacity to that layer. This keeps the system blue artwork from
            // bleeding back in at low opacity and makes 0% fully transparent.
            let opacity = CGFloat(max(0, min(1, tintOpacity)))
            if opacity > 0,
                let folderLayer = renderImage(size: rect.size, drawing: {
                    drawRecoloredFolder(tint: tint, in: $0)
                })
            {
                folderLayer.draw(
                    in: rect, from: .zero, operation: .sourceOver, fraction: opacity)
            }

            if let customImage {
                drawCustomImage(
                    customImage, folderColor: tint.referenceColor, style: style, customColor: symbolColor, in: rect,
                    size: symbolSize, offset: iconOffset)
            } else if isEmoji {
                drawEmoji(
                    symbolName, folderColor: tint.referenceColor, customSymbolColor: symbolColor,
                    style: style, in: rect, size: symbolSize, offset: iconOffset)
            } else {
                drawSymbol(
                    symbolName, folderColor: tint.referenceColor, customSymbolColor: symbolColor,
                    style: style, in: rect, size: symbolSize, offset: iconOffset)
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
        let context = NSGraphicsContext(bitmapImageRep: rep)
        context?.imageInterpolation = .high
        context?.shouldAntialias = true
        context?.cgContext.setAllowsAntialiasing(true)
        context?.cgContext.setShouldAntialias(true)
        NSGraphicsContext.current = context
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
        in rect: NSRect, size: CGFloat, offset: CGSize
    ) {
        guard !name.isEmpty else { return }

        let finalColor = resolvedIconColor(
            folderColor: folderColor, customSymbolColor: customSymbolColor, style: style)

        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .bold)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: finalColor))

        guard
            let symbolImage = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
        else { return }

        let x = (rect.width - symbolImage.size.width) / 2 + offset.width
        let y = (rect.height - symbolImage.size.height) / 2 - 40 + offset.height
        let symbolRect = NSRect(origin: CGPoint(x: x, y: y), size: symbolImage.size)

        if style == .vibrant {
            blendDraw(.multiply) {
                symbolImage.draw(in: symbolRect)
            }
        } else {
            symbolImage.draw(in: symbolRect)
        }
    }

    private static func drawEmoji(
        _ emoji: String, folderColor: NSColor, customSymbolColor: NSColor, style: IconStyle,
        in rect: NSRect, size: CGFloat, offset: CGSize
    ) {
        guard !emoji.isEmpty else { return }

        let font = NSFont.systemFont(ofSize: size)
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if !containsEmoji(emoji) {
            attributes[.foregroundColor] = resolvedIconColor(
                folderColor: folderColor, customSymbolColor: customSymbolColor, style: style)
        }
        let string = NSAttributedString(string: emoji, attributes: attributes)
        let stringSize = string.size()

        let x = (rect.width - stringSize.width) / 2 + offset.width
        let y = (rect.height - stringSize.height) / 2 - 40 + offset.height

        string.draw(in: NSRect(origin: CGPoint(x: x, y: y), size: stringSize))
    }

    private static func drawCustomImage(
        _ image: NSImage, folderColor: NSColor, style: IconStyle, customColor: NSColor, in rect: NSRect, size: CGFloat,
        offset: CGSize
    ) {
        // Aspect-fit the image into the square slot so non-square logos keep
        // their proportions instead of being stretched.
        let aspect = image.size.height > 0 ? image.size.width / image.size.height : 1
        let fitSize = aspect >= 1
            ? NSSize(width: size, height: size / aspect)
            : NSSize(width: size * aspect, height: size)
        let targetRect = NSRect(
            x: rect.midX - fitSize.width / 2 + offset.width,
            y: rect.midY - fitSize.height / 2 - 40 + offset.height,
            width: fitSize.width, height: fitSize.height)

        switch style {
        case .color, .inverted:
            // Keep enough source resolution for vector-derived images. SVGs
            // arrive as a 1024 px raster; shrinking that mask before tinting
            // makes diagonal and curved edges visibly pixelated.
            let maxDimension = max(1024, max(fitSize.width, fitSize.height) * 2)
            let tintColor = resolvedIconColor(
                folderColor: folderColor, customSymbolColor: customColor, style: style)
            if let tinted = tint(image, with: tintColor, maxDimension: maxDimension) {
                tinted.draw(in: targetRect)
            } else {
                image.draw(in: targetRect)
            }
        case .vibrant:
            blendDraw(.multiply) {
                image.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 0.4)
            }
        case .original:
            image.draw(in: targetRect)
        }
    }

    private static func resolvedIconColor(
        folderColor: NSColor, customSymbolColor: NSColor, style: IconStyle
    ) -> NSColor {
        switch style {
        case .vibrant:
            return NSColor(white: 0.1, alpha: 0.3)
        case .original:
            return .black
        case .color:
            return customSymbolColor
        case .inverted:
            guard let rgbFolder = folderColor.usingColorSpace(.sRGB) else { return .white }
            return NSColor(
                red: 1.0 - rgbFolder.redComponent,
                green: 1.0 - rgbFolder.greenComponent,
                blue: 1.0 - rgbFolder.blueComponent,
                alpha: 1.0)
        }
    }

    private static func containsEmoji(_ value: String) -> Bool {
        value.unicodeScalars.contains {
            $0.properties.isEmojiPresentation
                || ($0.properties.isEmoji && $0.value > 0x238C)
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

    /// Applies the same rendered icon to every folder. The method accepts PNG
    /// data so callers can safely move the work off the main actor.
    nonisolated static func applyIcon(_ imageData: Data, to folderURLs: [URL]) -> [Bool] {
        guard let image = NSImage(data: imageData) else {
            return Array(repeating: false, count: folderURLs.count)
        }

        return folderURLs.map { folderURL in
            withSecurityScopedAccess(to: folderURL) {
                NSWorkspace.shared.setIcon(image, forFile: folderURL.path, options: [])
            }
        }
    }

    enum ResetError: LocalizedError {
        case cannotResetIcon

        var errorDescription: String? {
            "Could not restore the default folder icon"
        }
    }

    /// Uses the same system API as icon application, avoiding a partial reset
    /// where the Icon file is deleted but Finder's custom-icon flag remains.
    nonisolated static func resetIcon(for folderURL: URL) throws {
        let didReset = withSecurityScopedAccess(to: folderURL) {
            NSWorkspace.shared.setIcon(nil, forFile: folderURL.path, options: [])
        }
        guard didReset else {
            throw ResetError.cannotResetIcon
        }
    }

    nonisolated private static func withSecurityScopedAccess<T>(
        to url: URL, operation: () -> T
    ) -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return operation()
    }
}
