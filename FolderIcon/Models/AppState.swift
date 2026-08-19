import AppKit
import Observation
import SwiftUI

enum ContentTab: String, CaseIterable {
    case color = "Color"
    case icon = "Icon"
    case details = "Details"
    case history = "History"
}

enum IconType: String, CaseIterable, Codable {
    case symbols = "Symbols"
    case emojis = "Emojis"
    case custom = "Custom"
}

enum IconStyle: String, CaseIterable, Codable {
    case vibrant = "Vibrant"
    case original = "Original"
    case color = "Color"
    case inverted = "Inverted"
}

enum TintMode: String, CaseIterable, Codable {
    case solid = "Solid"
    case gradient = "Gradient"
}

enum GradientSlot {
    case start
    case end
}

/// What gets painted over the folder icon (preserving its alpha).
enum FolderTint {
    case solid(NSColor)
    case gradient(start: NSColor, end: NSColor, angle: Double)

    /// Single representative color, e.g. for the inverted symbol style.
    var referenceColor: NSColor {
        switch self {
        case .solid(let color):
            return color
        case .gradient(let start, let end, _):
            guard
                let s = start.usingColorSpace(.sRGB),
                let e = end.usingColorSpace(.sRGB)
            else { return start }
            return NSColor(
                red: (s.redComponent + e.redComponent) / 2,
                green: (s.greenComponent + e.greenComponent) / 2,
                blue: (s.blueComponent + e.blueComponent) / 2,
                alpha: 1)
        }
    }
}

struct HSBColor: Equatable, Codable {
    var hue: Double
    var saturation: Double
    var brightness: Double

    init(hue: Double, saturation: Double, brightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }

    init(color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        self.init(
            hue: Double(nsColor.hueComponent),
            saturation: Double(nsColor.saturationComponent),
            brightness: Double(nsColor.brightnessComponent))
    }

    var color: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    var nsColor: NSColor {
        let base = NSColor(color)
        return base.usingColorSpace(.sRGB) ?? base
    }

    var hex: String {
        let c = nsColor
        return String(
            format: "%02X%02X%02X",
            Int(c.redComponent * 255),
            Int(c.greenComponent * 255),
            Int(c.blueComponent * 255))
    }
}

/// Snapshot of every input that affects the rendered folder icon.
/// Used as the debounce key for preview rendering.
struct RenderConfiguration: Equatable {
    var tintMode: TintMode
    var folderColor: HSBColor
    var gradientStart: HSBColor
    var gradientEnd: HSBColor
    var gradientAngle: Double
    var tintOpacity: Double
    var iconType: IconType
    var symbolName: String
    var emoji: String
    var symbolSize: CGFloat
    var iconStyle: IconStyle
    var iconColor: HSBColor
    var customImageID: ObjectIdentifier?
    var folderCount: Int

    init(_ state: AppState) {
        tintMode = state.tintMode
        folderColor = state.folderColor
        gradientStart = state.gradientStart
        gradientEnd = state.gradientEnd
        gradientAngle = state.gradientAngle
        tintOpacity = state.tintOpacity
        iconType = state.selectedIconType
        symbolName = state.selectedSymbol
        emoji = state.selectedEmoji
        symbolSize = state.symbolSize
        iconStyle = state.iconStyle
        iconColor = state.iconColor
        customImageID = state.customImage.map(ObjectIdentifier.init)
        folderCount = state.folderURLs.count
    }
}

/// Serializable snapshot of every setting that produced an applied icon.
/// Persisted alongside each history image so a history entry can be
/// re-applied (restore settings + colorize) later.
struct IconSnapshot: Codable {
    var tintMode: TintMode
    var folderColor: HSBColor
    var gradientStart: HSBColor
    var gradientEnd: HSBColor
    var gradientAngle: Double
    var tintOpacity: Double
    var iconType: IconType
    var symbolName: String
    var emoji: String
    var symbolSize: Double
    var iconStyle: IconStyle
    var iconColor: HSBColor
    var customImageData: Data?

    init(state: AppState) {
        tintMode = state.tintMode
        folderColor = state.folderColor
        gradientStart = state.gradientStart
        gradientEnd = state.gradientEnd
        gradientAngle = state.gradientAngle
        tintOpacity = state.tintOpacity
        iconType = state.selectedIconType
        symbolName = state.selectedSymbol
        emoji = state.selectedEmoji
        symbolSize = Double(state.symbolSize)
        iconStyle = state.iconStyle
        iconColor = state.iconColor
        customImageData = state.customImage?.pngData
    }
}

@Observable
final class AppState {
    let history = HistoryStore()

    var folderURLs: [URL] = []
    var selectedTab: ContentTab = .color

    // Color tab
    var tintMode: TintMode = .solid
    var folderColor = HSBColor(hue: 0.7, saturation: 0.8, brightness: 0.9)
    var gradientStart = HSBColor(hue: 0.7, saturation: 0.8, brightness: 0.9)
    var gradientEnd = HSBColor(hue: 0.92, saturation: 0.8, brightness: 0.9)
    var gradientAngle: Double = 0
    var activeGradientSlot: GradientSlot = .start

    // Icon tab
    var selectedIconType: IconType = .symbols
    var selectedSymbol: String = ""
    var selectedEmoji: String = ""
    var customImage: NSImage?
    var searchText: String = ""
    var selectedCategory: String = "All Symbols"

    // Details tab
    var symbolSize: CGFloat = 160
    var iconStyle: IconStyle = .vibrant
    var iconColor = HSBColor(hue: 0.5, saturation: 0.7, brightness: 0.8)
    var tintOpacity: Double = 1.0

    var renderConfiguration: RenderConfiguration {
        RenderConfiguration(self)
    }

    var folderColorHex: String {
        folderColor.hex
    }

    func restore(from snapshot: IconSnapshot) {
        tintMode = snapshot.tintMode
        folderColor = snapshot.folderColor
        gradientStart = snapshot.gradientStart
        gradientEnd = snapshot.gradientEnd
        gradientAngle = snapshot.gradientAngle
        tintOpacity = snapshot.tintOpacity
        selectedIconType = snapshot.iconType
        selectedSymbol = snapshot.symbolName
        selectedEmoji = snapshot.emoji
        symbolSize = CGFloat(snapshot.symbolSize)
        iconStyle = snapshot.iconStyle
        iconColor = snapshot.iconColor
        if let data = snapshot.customImageData {
            customImage = NSImage(data: data)
        } else {
            customImage = nil
        }
        selectedTab = .color
    }
}

extension NSImage {
    var pngData: Data? {
        guard
            let tiff = tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
