import Foundation

struct IconCategory: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let symbols: [String]
}

struct SFSymbolsLibrary {
    static let categories: [IconCategory] = [
        IconCategory(
            name: "Communication",
            symbols: [
                "mic", "mic.fill", "mic.circle", "message", "message.fill", "bubble.left",
                "bubble.left.fill", "phone", "phone.fill", "envelope", "envelope.fill",
                "paperplane", "paperplane.fill", "antenna.radiowaves.left.and.right", "wifi",
            ]),
        IconCategory(
            name: "Devices",
            symbols: [
                "display", "laptopcomputer", "iphone", "ipad", "applewatch", "applewatch.watchface",
                "airpods", "airpodspro", "homepod", "appletv", "gamecontroller", "headphones",
                "speaker.wave.2", "keyboard", "magicmouse", "printer", "scanner",
            ]),
        IconCategory(
            name: "Objects",
            symbols: [
                "star", "star.fill", "heart", "heart.fill", "flag", "flag.fill", "bolt",
                "bolt.fill", "bell", "bell.fill", "camera", "camera.fill", "folder", "folder.fill",
                "gearshape", "gearshape.fill", "leaf", "leaf.fill", "umbrella", "umbrella.fill",
                "cloud", "cloud.fill", "sun.max", "sun.max.fill", "moon", "moon.fill", "trash",
                "trash.fill", "pencil", "link", "briefcase", "archivebox", "calendar", "clock",
                "calendar", "clock", "plus.app", "shield", "lock", "lock.fill", "lock.open",
                "lock.open.fill", "key",
                "key.fill",
            ]),
        IconCategory(
            name: "Media",
            symbols: [
                "play", "play.fill", "pause", "pause.fill", "stop", "stop.fill",
                "forward", "forward.fill", "backward", "backward.fill",
                "music.note", "music.note.list", "music.quarternote.3",
                "photo", "photo.fill", "video", "video.fill", "tv", "tv.fill",
            ]),
        IconCategory(
            name: "Nature",
            symbols: [
                "sun.max", "moon", "cloud", "cloud.rain", "snow", "wind", "tornado", "hurricane",
                "bolt",
                "thermometer.sun", "thermometer.snowflake", "drop", "flame", "tree",
            ]),
        IconCategory(
            name: "All Symbols",
            symbols: [
                "star", "heart", "bell", "flag", "bolt", "camera", "folder", "gearshape", "leaf",
                "umbrella", "cloud", "sun.max", "house", "magnifyingglass", "envelope", "phone",
                "paperplane", "archivebox", "briefcase", "calendar", "clock", "message", "video",
                "mic", "music.note", "photo", "map", "location", "shield", "lock",
                "lock.open", "key", "cart", "bag", "creditcard", "gift", "gamecontroller",
                "headphones", "speaker.wave.2", "display", "laptopcomputer", "iphone",
                "applewatch.watchface", "trash", "pencil", "link", "plus", "minus", "checkmark",
                "xmark", "info.circle", "questionmark.circle", "exclamationmark.triangle",
                "arrow.up", "arrow.down", "arrow.left", "arrow.right", "square.and.arrow.up",
                "square.and.arrow.down", "pencil.tip", "lasso", "folder.badge.plus",
            ]),
    ]

    static func symbols(for categoryName: String) -> [String] {
        // Return unique symbols to avoid SwiftUI ID collision warnings
        let rawSymbols = categories.first { $0.name == categoryName }?.symbols ?? []
        var uniqueSymbols = [String]()
        var seen = Set<String>()
        for symbol in rawSymbols {
            if !seen.contains(symbol) {
                uniqueSymbols.append(symbol)
                seen.insert(symbol)
            }
        }
        return uniqueSymbols
    }

    static var allSymbols: [String] {
        categories.flatMap { $0.symbols }
    }
}
