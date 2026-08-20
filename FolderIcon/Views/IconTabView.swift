import AppKit
import ImageIO
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

struct IconTabView: View {
    @Bindable var state: AppState
    @State private var isCustomImageDropTargeted = false
    @State private var customImageError: String?
    @State private var svgCode = ""

    var body: some View {
        VStack(spacing: 15) {
            typePickerView

            Group {
                switch state.selectedIconType {
                case .symbols:
                    symbolsView
                case .emojis:
                    emojiView
                case .custom:
                    customView
                }
            }

            Spacer()
        }
    }

    private var typePickerView: some View {
        HStack(spacing: 0) {
            ForEach(IconType.allCases, id: \.self) { type in
                let isActive = state.selectedIconType == type
                Button(action: { state.selectedIconType = type }) {
                    Text(type.rawValue)
                        .font(.system(size: 12, weight: isActive ? .bold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isActive ? Color.white : Color.clear)
                        .cornerRadius(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(2)
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var emojiView: some View {
        VStack(spacing: 14) {
            SectionCard(title: "Emoji or text", subtitle: "Up to 4 characters") {
                TextField("e.g. 🚀 or OK", text: $state.selectedEmoji)
                    .textFieldStyle(.plain)
                    .font(.system(size: 40))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                    .onChange(of: state.selectedEmoji) { _, value in
                        state.selectedEmoji = Self.limitedEmojiInput(value)
                    }
            }

            SectionCard(title: "Quick picks", subtitle: "Click an emoji to use it") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                    spacing: 8
                ) {
                    ForEach(Self.emojiPresets, id: \.self) { emoji in
                        Button(action: { state.selectedEmoji = emoji }) {
                            Text(emoji)
                                .font(.system(size: 24))
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(state.selectedEmoji == emoji ? Color.blue.opacity(0.18) : Color.white.opacity(0.08))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .help("Use \(emoji)")
                    }
                }
            }
        }
    }

    private static let emojiPresets = [
        "📁", "⭐️", "❤️", "🔥", "🚀", "💡", "🎯", "✅",
        "📷", "🎵", "🎮", "💻", "🔒", "📦", "🗂️", "🌈",
        "🎨", "📝", "📚", "🧪", "🔧", "⚙️", "🛠️", "📊",
        "💼", "💰", "🛒", "🏠", "✈️", "🌍", "☕️", "🍀",
        "🐶", "🐱", "🦊", "🐼", "🌸", "🌲", "☀️", "🌙",
        "⚡️", "❄️", "🌊", "🎬", "🎤", "🏆", "🎁", "💎",
        "👤", "👥", "💬", "📧", "📞", "🔔", "🗓️", "⏰",
        "🚗", "🚲", "🧭", "📍", "🔑", "🧩", "🎲", "🪄",
        "🍎", "🍕", "⚽️", "🏋️", "🧠", "🤖", "🧸", "🚩"
    ]

    static func limitedEmojiInput(_ value: String) -> String {
        String(value.prefix(4))
    }

    private var customView: some View {
        SectionCard(title: "Custom Image", subtitle: "PNG, JPEG, WebP or SVG") {
            VStack(spacing: 14) {
                Button(action: chooseCustomImage) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                isCustomImageDropTargeted
                                    ? Color.blue.opacity(0.1) : Color.clear)
                            .frame(height: 110)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isCustomImageDropTargeted ? Color.blue : Color.gray.opacity(0.5),
                                        style: StrokeStyle(lineWidth: 1, dash: [4])))

                        if let img = state.customImage {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 76, height: 76)
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 30))
                                Text("Choose or drop an image")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(isCustomImageDropTargeted ? .blue : .gray)
                        }
                    }
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .onDrop(of: [.fileURL, .svg, .image], isTargeted: $isCustomImageDropTargeted) {
                    providers in
                    handleImageDrop(providers: providers)
                }
                .help("Choose an image file or drop one here")

                if let customImageError {
                    Label(customImageError, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if state.customImage != nil {
                    Button(action: {
                        state.customImage = nil
                        customImageError = nil
                        svgCode = ""
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove image")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("Clear the custom image")
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label("Paste SVG code", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12, weight: .bold))

                    Text("Open SimpleIcons, copy the full <svg>…</svg> code, paste it here, then apply it as your custom icon.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextEditor(text: $svgCode)
                        .font(.system(size: 10, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .frame(height: 100)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1))

                    Button(action: applySVGCode) {
                        Label("Apply SVG code", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(svgCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(svgCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Button(action: {
                    if let url = URL(string: "https://simpleicons.org") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Get logos on SimpleIcons.org")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredSymbols: [String] {
        let query = normalizedSymbolInput.lowercased()
        return SFSymbolsLibrary.symbols(for: state.selectedCategory).filter {
            query.isEmpty || $0.lowercased().contains(query)
        }
    }

    private var normalizedSymbolInput: String {
        state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasInvalidSymbolInput: Bool {
        !normalizedSymbolInput.isEmpty
            && NSImage(systemSymbolName: normalizedSymbolInput, accessibilityDescription: nil) == nil
    }

    private var searchBarView: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search or paste an SF Symbol name", text: $state.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .onChange(of: state.searchText) { _, newValue in
                let name = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                state.selectedSymbol =
                    NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil
                    ? "" : name
            }

            Button(action: {
                let path = "/Applications/SF Symbols.app"
                if FileManager.default.fileExists(atPath: path) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                } else if let url = URL(string: "https://developer.apple.com/sf-symbols/") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .help("Open SF Symbols App")
            }
            .buttonStyle(.plain)

            Button(action: {
                state.searchText = ""
                state.selectedSymbol = ""
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(
                        state.searchText.isEmpty && state.selectedSymbol.isEmpty
                            ? .gray.opacity(0.4) : .red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .help("Clear current symbol")
            }
            .buttonStyle(.plain)
            .disabled(state.searchText.isEmpty && state.selectedSymbol.isEmpty)
        }
    }

    private var symbolsView: some View {
        VStack(spacing: 12) {
            SectionCard(title: "Symbols", subtitle: categorySubtitle) {
                VStack(spacing: 12) {
                    searchBarView

                    if hasInvalidSymbolInput {
                        Label("This SF Symbol name is not available on this Mac", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    symbolInfoCard

                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12
                        ) {
                            ForEach(filteredSymbols, id: \.self) { sym in
                                Button(action: {
                                    state.searchText = sym
                                    state.selectedSymbol = sym
                                }) {
                                    Image(systemName: sym)
                                        .font(.system(size: 18))
                                        .frame(width: 40, height: 40)
                                        .background(
                                            state.selectedSymbol == sym
                                                ? Color.blue.opacity(0.2) : Color.white.opacity(0.5))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8).stroke(
                                                state.selectedSymbol == sym ? Color.blue : Color.clear,
                                                lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var symbolInfoCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 15))

            VStack(alignment: .leading, spacing: 3) {
                Text("Use any SF Symbol")
                    .font(.system(size: 11, weight: .semibold))

                Text("Click the grid button to open SF Symbols, copy any symbol name, and paste it here. The icon updates automatically.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text("Copy and paste this example:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text("folder.badge.plus")
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(5)

                    Button(action: copySymbolExample) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(5)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Copy example")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.16), lineWidth: 1)
        )
    }

    private var categorySubtitle: String {
        if !normalizedSymbolInput.isEmpty, !hasInvalidSymbolInput, filteredSymbols.isEmpty {
            return "Custom symbol"
        }
        return "\(filteredSymbols.count) symbols"
    }

    private func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) ?? providers.first(where: { Self.imageTypeIdentifier(for: $0) != nil }) else {
            customImageError = "Drop a supported image file"
            return false
        }

        customImageError = nil
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                let url = Self.droppedFileURL(from: item)
                DispatchQueue.main.async {
                    guard let url else {
                        customImageError = "Could not read the dropped file"
                        return
                    }
                    loadCustomImage(from: url)
                }
            }
        } else if let typeIdentifier = Self.imageTypeIdentifier(for: provider) {
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                DispatchQueue.main.async {
                    guard let data else {
                        customImageError = error?.localizedDescription ?? "Could not load this image"
                        return
                    }
                    loadCustomImage(from: data, typeIdentifier: typeIdentifier)
                }
            }
        }
        return true
    }

    nonisolated static func imageTypeIdentifier(for provider: NSItemProvider) -> String? {
        provider.registeredTypeIdentifiers.first {
            UTType($0)?.conforms(to: .image) == true
        }
    }

    private func copySymbolExample() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("folder.badge.plus", forType: .string)
    }

    private func chooseCustomImage() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Custom Image"
        panel.prompt = "Choose"
        panel.allowedContentTypes = [.png, .jpeg, .webP, .svg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadCustomImage(from: url)
    }

    private func loadCustomImage(from url: URL) {
        customImageError = nil
        Task { @MainActor in
            let didStart = url.startAccessingSecurityScopedResource()
            defer {
                if didStart {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let cgImage = await Self.loadCustomImage(from: url) else {
                customImageError = "Could not load this image"
                return
            }
            state.customImage = NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height))
            customImageError = nil
        }
    }

    private func loadCustomImage(from data: Data, typeIdentifier: String) {
        customImageError = nil
        Task { @MainActor in
            guard let cgImage = await Self.loadCustomImage(from: data, typeIdentifier: typeIdentifier) else {
                customImageError = "Could not load this image"
                return
            }
            state.customImage = NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height))
            customImageError = nil
        }
    }

    private func applySVGCode() {
        let code = svgCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        guard code.utf8.count <= 1_000_000 else {
            customImageError = "SVG code must be smaller than 1 MB"
            return
        }
        guard code.range(of: "<svg", options: .caseInsensitive) != nil else {
            customImageError = "Paste the full SVG code, including the <svg> tag"
            return
        }

        loadCustomImage(from: Data(code.utf8), typeIdentifier: UTType.svg.identifier)
    }

    nonisolated static func loadCustomImage(from url: URL) async -> CGImage? {
        if url.pathExtension.lowercased() == "svg" {
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: 1024, height: 1024),
                scale: 1,
                representationTypes: .thumbnail)
            if let representation = try? await QLThumbnailGenerator.shared
                .generateBestRepresentation(for: request)
            {
                return representation.cgImage
            }
        }

        return loadThumbnail(from: url)
    }

    nonisolated static func loadCustomImage(from data: Data, typeIdentifier: String) async -> CGImage? {
        let type = UTType(typeIdentifier)
        let isSVG = type?.conforms(to: .svg) == true
            || data.prefix(512).range(of: Data("<svg".utf8)) != nil

        if isSVG {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("svg")
            defer { try? FileManager.default.removeItem(at: url) }

            do {
                try data.write(to: url, options: .atomic)
                if let image = await loadCustomImage(from: url) {
                    return image
                }
            } catch {
                return nil
            }
        }

        return NSImage(data: data)?.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil)
    }

    nonisolated static func droppedFileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        {
            return URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let value = item as? String {
            return URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    nonisolated static func loadThumbnail(from url: URL) -> CGImage? {
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            if let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0, options as CFDictionary)
            {
                return image
            }
        }

        // ImageIO does not rasterize every SVG variant. AppKit can decode SVG
        // files, so use it as a vector fallback and render a bounded bitmap.
        guard let vectorImage = NSImage(contentsOf: url) else { return nil }
        let sourceSize = vectorImage.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let targetLargestDimension: CGFloat = 1024
        let aspect = sourceSize.width / sourceSize.height
        let targetSize = aspect >= 1
            ? NSSize(width: targetLargestDimension, height: targetLargestDimension / aspect)
            : NSSize(width: targetLargestDimension * aspect, height: targetLargestDimension)
        guard
            let representation = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: max(1, Int(targetSize.width)),
                pixelsHigh: max(1, Int(targetSize.height)),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0)
        else { return nil }
        representation.size = targetSize

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
        vectorImage.draw(in: NSRect(origin: .zero, size: targetSize))
        NSGraphicsContext.restoreGraphicsState()
        return representation.cgImage
    }
}
