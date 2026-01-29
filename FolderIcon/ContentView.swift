import AppKit
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
    enum IconStyle: String, CaseIterable {
        case vibrant = "Vibrant"
        case original = "Original"
        case color = "Color"
        case inverted = "Inverted"
    }

    struct ContentView: View {
        @State private var folderURL: URL?
        @State private var folderUrls: [URL] = []

        // Tab Selection
        @State private var selectedTab: String = "Color"
        let tabs = ["Color", "Icon", "Details"]

        // Color Tab State
        @State private var hue: Double = 0.7
        @State private var saturation: Double = 0.8
        @State private var brightness: Double = 0.9

        // Icon Tab State
        @State private var selectedIconType: String = "Symbols"
        @State private var selectedSymbol: String = "star.fill"
        @State private var selectedEmoji: String = ""
        @State private var customImagePath: String? = nil
        @State private var customImage: NSImage? = nil
        @State private var searchText: String = ""
        @State private var selectedCategory: String = "All Symbols"

        // Details Tab State
        @State private var symbolSize: CGFloat = 160
        @State private var iconStyle: IconStyle = .vibrant
        @State private var iconColorHSB: (hue: Double, sat: Double, bri: Double) = (0.5, 0.7, 0.8)
        @State private var tintOpacity: Double = 0.5

        var folderColor: Color {
            Color(hue: hue, saturation: saturation, brightness: brightness)
        }

        var currentIconColor: Color {
            Color(hue: iconColorHSB.hue, saturation: iconColorHSB.sat, brightness: iconColorHSB.bri)
        }

        func getPreviewImage() -> NSImage? {
            if selectedIconType == "Custom", let img = customImage {
                return FolderProcessor.createCustomFolder(
                    folderColor: NSColor(folderColor),
                    symbolName: "",
                    symbolSize: symbolSize,
                    symbolColor: NSColor(currentIconColor),
                    style: iconStyle,
                    tintOpacity: tintOpacity,
                    customImage: img
                )
            }

            let symbol = selectedIconType == "Emojis" ? selectedEmoji : selectedSymbol
            return FolderProcessor.createCustomFolder(
                folderColor: NSColor(folderColor),
                symbolName: symbol,
                symbolSize: symbolSize,
                symbolColor: NSColor(currentIconColor),
                style: iconStyle,
                tintOpacity: tintOpacity,
                isEmoji: selectedIconType == "Emojis" && !selectedEmoji.isEmpty
            )
        }

        var body: some View {
            VStack(spacing: 0) {
                Spacer().frame(height: 20)

                // Preview Area
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.05))
                        .frame(height: 180)
                        .padding(.horizontal)

                    if let firstUrl = folderUrls.first {
                        VStack {
                            if let preview = getPreviewImage() {
                                Image(nsImage: preview)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                            }
                            Text(firstUrl.lastPathComponent)
                                .font(.system(size: 11))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                        Button(action: { folderUrls.removeAll() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(4)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 25)
                        .padding(.top, 10)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 30))
                                .foregroundColor(.secondary)
                            Text("Перетягніть каталоги сюди")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    }
                }
                .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                }

                // Tabs
                HStack(spacing: 20) {
                    ForEach(tabs, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            Text(tab)
                                .font(
                                    .system(size: 14, weight: selectedTab == tab ? .bold : .medium)
                                )
                                .foregroundColor(selectedTab == tab ? .primary : .gray)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    selectedTab == tab ? Color.gray.opacity(0.1) : Color.clear
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                    }
                }
                .padding(.top, 20)

                // Tab Content
                VStack {
                    switch selectedTab {
                    case "Color":
                        ColorTabView(
                            hue: $hue, saturation: $saturation, brightness: $brightness,
                            tintOpacity: $tintOpacity, hex: hexFromHSB())
                    case "Icon":
                        IconTabView(
                            selectedType: $selectedIconType,
                            selectedSymbol: $selectedSymbol,
                            selectedEmoji: $selectedEmoji,
                            searchText: $searchText,
                            selectedCategory: $selectedCategory,
                            customImage: $customImage)
                    case "Details":
                        DetailsTabView(
                            size: $symbolSize, style: $iconStyle, iconHue: $iconColorHSB.hue,
                            iconSat: $iconColorHSB.sat, iconBri: $iconColorHSB.bri,
                            selectedSymbol: selectedSymbol, selectedEmoji: selectedEmoji,
                            isEmoji: selectedIconType == "Emojis")
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
                .padding()

                // Footer
                HStack {
                    Button(action: { applyChanges() }) {
                        HStack {
                            Image(systemName: folderUrls.count > 0 ? "lock.open.fill" : "lock.fill")
                            Text(
                                "Colorize \(folderUrls.count > 0 ? "\(folderUrls.count) folder" : "folder")"
                            )
                        }
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(folderUrls.isEmpty ? Color.gray.opacity(0.3) : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(folderUrls.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .frame(width: 360, height: 740)
            .background(Color(red: 235 / 255, green: 236 / 255, blue: 237 / 255))
            .background(VisualEffectView(material: .underWindowBackground).ignoresSafeArea())
        }

        // Helper Functions
        func handleDrop(providers: [NSItemProvider]) -> Bool {
            var found = false
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url,
                        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                    {
                        DispatchQueue.main.async {
                            if !self.folderUrls.contains(url) {
                                self.folderUrls.append(url)
                            }
                        }
                        found = true
                    }
                }
            }
            return found
        }

        func hexFromHSB() -> String {
            let nsColor = NSColor(folderColor)
            guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return "000000" }
            let r = Int(rgbColor.redComponent * 255)
            let g = Int(rgbColor.greenComponent * 255)
            let b = Int(rgbColor.blueComponent * 255)
            return String(format: "%02X%02X%02X", r, g, b)
        }

        func applyChanges() {
            guard let img = getPreviewImage() else { return }
            for url in folderUrls {
                FolderProcessor.applyIcon(image: img, to: url)
            }
        }
    }

    // --- Subviews ---

    struct ColorTabView: View {
        @Binding var hue: Double
        @Binding var saturation: Double
        @Binding var brightness: Double
        @Binding var tintOpacity: Double
        let hex: String

        let presets: [Color] = [
            .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue,
            .indigo, .purple, .pink, .brown, .gray, .primary, .white, .black,
        ]

        var body: some View {
            VStack(spacing: 20) {
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hue: hue, saturation: saturation, brightness: brightness))
                        .frame(width: 40, height: 24)
                    Text(hex)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                }

                VStack(spacing: 25) {
                    HSBSlider(
                        value: $hue,
                        gradient: Gradient(
                            colors: (0...10).map {
                                Color(hue: Double($0) / 10.0, saturation: 1, brightness: 1)
                            }))
                    HSBSlider(
                        value: $saturation,
                        gradient: Gradient(colors: [
                            Color(hue: hue, saturation: 0, brightness: brightness),
                            Color(hue: hue, saturation: 1, brightness: brightness),
                        ]))
                    HSBSlider(
                        value: $brightness,
                        gradient: Gradient(colors: [
                            .black, Color(hue: hue, saturation: saturation, brightness: 1),
                        ]))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Opacity")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                        Slider(value: $tintOpacity, in: 0...1)
                            .controlSize(.small)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                    ForEach(presets, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 25, height: 25)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2).opacity(0.3))
                            .onTapGesture {
                                let nsColor =
                                    NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
                                hue = Double(nsColor.hueComponent)
                                saturation = Double(nsColor.saturationComponent)
                                brightness = Double(nsColor.brightnessComponent)
                            }
                    }
                }
                .padding(.top, 10)

                Spacer()
            }
        }
    }

    // CUSTOM SLIDER WITHOUT TRACK
    struct HSBSlider: View {
        @Binding var value: Double
        let gradient: Gradient

        var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Only the gradient background, NO system track
                    LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing)
                        .frame(height: 24)
                        .cornerRadius(12)

                    // Custom handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(radius: 2)
                        .offset(x: (CGFloat(value) * (geometry.size.width - 24.0)) + 2.0)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let newValue = Double(gesture.location.x / geometry.size.width)
                            value = max(0, min(1, newValue))
                        }
                )
            }
            .frame(height: 24)
        }
    }

    struct IconTabView: View {
        @Binding var selectedType: String
        @Binding var selectedSymbol: String
        @Binding var selectedEmoji: String
        @Binding var searchText: String
        @Binding var selectedCategory: String
        @Binding var customImage: NSImage?

        let types = ["Symbols", "Emojis", "Custom"]

        var body: some View {
            VStack(spacing: 15) {
                typePickerView

                Group {
                    if selectedType == "Emojis" {
                        emojiView
                    } else if selectedType == "Custom" {
                        customView
                    } else {
                        symbolsView
                    }
                }

                Spacer()
            }
        }

        private var typePickerView: some View {
            HStack(spacing: 15) {
                ForEach(types, id: \.self) { type in
                    Button(action: { selectedType = type }) {
                        Text(type)
                            .font(.system(size: 13, weight: selectedType == type ? .bold : .medium))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                selectedType == type ? Color.gray.opacity(0.1) : Color.clear
                            )
                            .cornerRadius(6)
                            .foregroundColor(selectedType == type ? .primary : .gray)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        private var emojiView: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Type or Paste Emoji")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)

                TextField("e.g. 🚀", text: $selectedEmoji)
                    .textFieldStyle(.plain)
                    .font(.system(size: 40))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
            }
            .padding(.top, 20)
        }

        private var customView: some View {
            VStack(spacing: 20) {
                Text("Drop any logo or image here")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundColor(.gray.opacity(0.5))
                        .frame(height: 120)

                    if let img = customImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                    } else {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                    }
                }
                .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                    if let provider = providers.first {
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url = url, let img = NSImage(contentsOf: url) {
                                DispatchQueue.main.async {
                                    self.customImage = img
                                }
                            }
                        }
                    }
                    return true
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
            .padding(.top, 20)
        }

        private var filteredSymbols: [String] {
            let symbols = IconData.SFSymbolsLibrary.symbols(for: selectedCategory)
            return symbols.filter {
                searchText.isEmpty || $0.lowercased().contains(searchText.lowercased())
            }
        }

        private var searchBarView: some View {
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search or enter name", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .onChange(of: searchText) { oldValue, newValue in
                    if IconData.SFSymbolsLibrary.allSymbols.contains(newValue) {
                        selectedSymbol = newValue
                    }
                }

                Button(action: {
                    let path = "/Applications/SF Symbols.app"
                    if FileManager.default.fileExists(atPath: path) {
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    } else {
                        if let url = URL(string: "https://developer.apple.com/sf-symbols/") {
                            NSWorkspace.shared.open(url)
                        }
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
            }
        }

        @ViewBuilder
        private func categoryButton(for cat: IconData.IconCategory) -> some View {
            Button(action: { selectedCategory = cat.name }) {
                Text(cat.name)
                    .font(
                        .system(
                            size: 11,
                            weight: selectedCategory == cat.name ? .bold : .regular
                        )
                    )
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        selectedCategory == cat.name
                            ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05)
                    )
                    .cornerRadius(6)
                    .foregroundColor(
                        selectedCategory == cat.name ? .blue : .primary
                    )
            }
            .buttonStyle(.plain)
        }

        private var symbolsView: some View {
            VStack(spacing: 12) {
                // Category Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(IconData.SFSymbolsLibrary.categories, id: \.id) { cat in
                            categoryButton(for: cat)
                        }
                    }
                }

                // Search & Manual Input
                searchBarView

                // Icons Grid
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12
                    ) {
                        ForEach(filteredSymbols, id: \.self) { sym in
                            Button(action: { selectedSymbol = sym }) {
                                Image(systemName: sym)
                                    .font(.system(size: 18))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        selectedSymbol == sym
                                            ? Color.blue.opacity(0.2) : Color.white.opacity(0.5)
                                    )
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8).stroke(
                                            selectedSymbol == sym ? Color.blue : Color.clear,
                                            lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    struct DetailsTabView: View {
        @Binding var size: CGFloat
        @Binding var style: IconStyle
        @Binding var iconHue: Double
        @Binding var iconSat: Double
        @Binding var iconBri: Double

        let selectedSymbol: String
        let selectedEmoji: String
        let isEmoji: Bool

        var body: some View {
            VStack(spacing: 20) {
                IconPreviewSection(
                    isEmoji: isEmoji,
                    selectedEmoji: selectedEmoji,
                    selectedSymbol: selectedSymbol,
                    previewColor: previewIconColor()
                )

                SizeSliderSection(size: $size)

                StylePickerSection(style: $style)

                if style == .color {
                    IconColorSection(hue: $iconHue, sat: $iconSat, bri: $iconBri)
                }

                Spacer()
            }
        }

        private func previewIconColor() -> Color {
            switch style {
            case .vibrant: return Color.black.opacity(0.4)
            case .original: return Color.black
            case .color: return Color(hue: iconHue, saturation: iconSat, brightness: iconBri)
            case .inverted: return Color.white
            }
        }
    }

    struct IconPreviewSection: View {
        let isEmoji: Bool
        let selectedEmoji: String
        let selectedSymbol: String
        let previewColor: Color

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(.gray.opacity(0.5))
                    .frame(width: 80, height: 80)

                if isEmoji && !selectedEmoji.isEmpty {
                    Text(selectedEmoji).font(.system(size: 40))
                } else if !selectedSymbol.isEmpty {
                    Image(systemName: selectedSymbol)
                        .font(.system(size: 40))
                        .foregroundColor(previewColor)
                }
            }
            .padding(.vertical, 10)
        }
    }

    struct SizeSliderSection: View {
        @Binding var size: CGFloat
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Size").font(.system(size: 12, weight: .bold))
                HSBSlider(
                    value: Binding(
                        get: { Double((size - 80.0) / 220.0) },
                        set: { size = CGFloat(80.0 + ($0 * 220.0)) }
                    ),
                    gradient: Gradient(colors: [.gray, .blue]))
            }
        }
    }

    struct StylePickerSection: View {
        @Binding var style: IconStyle
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Style").font(.system(size: 12, weight: .bold))
                HStack(spacing: 0) {
                    ForEach(IconStyle.allCases, id: \.self) { s in
                        Button(action: { style = s }) {
                            Text(s.rawValue)
                                .font(.system(size: 11))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(style == s ? Color.white : Color.clear)
                                .cornerRadius(6)
                                .shadow(radius: style == s ? 1 : 0)
                        }
                        .buttonStyle(.plain)
                        .padding(2)
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    struct IconColorSection: View {
        @Binding var hue: Double
        @Binding var sat: Double
        @Binding var bri: Double
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Color").font(.system(size: 12, weight: .bold))
                HStack(spacing: 15) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hue: hue, saturation: sat, brightness: bri))
                        .frame(width: 40, height: 30)
                    VStack(spacing: 15) {
                        HSBSlider(
                            value: $hue,
                            gradient: Gradient(
                                colors: (0...10).map {
                                    Color(hue: Double($0) / 10.0, saturation: 1, brightness: 1)
                                }))
                        HSBSlider(
                            value: $sat,
                            gradient: Gradient(colors: [
                                .white, Color(hue: hue, saturation: 1, brightness: bri),
                            ]))
                    }
                }
            }
        }
    }

    // --- Core Logic Merged ---
    struct FolderProcessor {
        static func createCustomFolder(
            folderColor: NSColor,
            symbolName: String,
            symbolSize: CGFloat,
            symbolColor: NSColor,
            style: IconStyle,
            tintOpacity: Double = 0.5,
            isEmoji: Bool = false,
            customImage: NSImage? = nil
        ) -> NSImage? {
            let baseFolder = NSWorkspace.shared.icon(for: .folder)
            let canvasSize = NSSize(width: 512, height: 512)
            let newImage = NSImage(size: canvasSize)

            newImage.lockFocus()
            let rect = NSRect(origin: .zero, size: canvasSize)
            baseFolder.draw(in: rect)

            // 1. Tint the folder
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .sourceAtop

            // Use the user-defined opacity
            folderColor.withAlphaComponent(CGFloat(tintOpacity)).set()
            rect.fill()

            NSGraphicsContext.restoreGraphicsState()

            // 2. Draw Symbol/Emoji/Custom
            if let custom = customImage {
                drawCustomImage(
                    custom, style: style, customColor: symbolColor, in: rect, size: symbolSize)
            } else if isEmoji {
                drawEmoji(symbolName, in: rect, size: symbolSize)
            } else {
                drawSymbol(
                    symbolName, folderColor: folderColor, customSymbolColor: symbolColor,
                    style: style, in: rect, size: symbolSize)
            }

            newImage.unlockFocus()
            return newImage
        }

        private static func drawSymbol(
            _ name: String, folderColor: NSColor, customSymbolColor: NSColor, style: IconStyle,
            in rect: NSRect, size: CGFloat
        ) {
            guard !name.isEmpty else { return }

            var config = NSImage.SymbolConfiguration(pointSize: size, weight: .bold)

            var finalColor: NSColor

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
                        alpha: 1.0
                    )
                } else {
                    finalColor = .white
                }
            }

            config = config.applying(NSImage.SymbolConfiguration(hierarchicalColor: finalColor))

            if let symbolImage = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            {
                let x = (rect.width - symbolImage.size.width) / 2
                let y = (rect.height - symbolImage.size.height) / 2 - 20

                if style == .vibrant {
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current?.compositingOperation = .multiply
                    symbolImage.draw(
                        in: NSRect(origin: CGPoint(x: x, y: y), size: symbolImage.size))
                    NSGraphicsContext.restoreGraphicsState()
                } else {
                    symbolImage.draw(
                        in: NSRect(origin: CGPoint(x: x, y: y), size: symbolImage.size))
                }
            }
        }

        private static func drawEmoji(_ emoji: String, in rect: NSRect, size: CGFloat) {
            guard !emoji.isEmpty else { return }

            let font = NSFont.systemFont(ofSize: size)
            let string = NSAttributedString(string: emoji, attributes: [.font: font])
            let stringSize = string.size()

            let x = (rect.width - stringSize.width) / 2
            let y = (rect.height - stringSize.height) / 2 - 20

            string.draw(in: NSRect(origin: CGPoint(x: x, y: y), size: stringSize))
        }

        private static func drawCustomImage(
            _ image: NSImage, style: IconStyle, customColor: NSColor, in rect: NSRect, size: CGFloat
        ) {
            let targetSize = NSSize(width: size, height: size)
            let x = (rect.width - targetSize.width) / 2
            let y = (rect.height - targetSize.height) / 2 - 20
            let targetRect = NSRect(origin: CGPoint(x: x, y: y), size: targetSize)

            if style == .color {
                // If style is color, we try to tint the custom image
                if let tinted = image.copy() as? NSImage {
                    tinted.lockFocus()
                    customColor.set()
                    let imageRect = NSRect(origin: .zero, size: tinted.size)
                    imageRect.fill(using: .sourceAtop)
                    tinted.unlockFocus()
                    tinted.draw(in: targetRect)
                }
            } else if style == .vibrant {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current?.compositingOperation = .multiply
                image.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 0.4)
                NSGraphicsContext.restoreGraphicsState()
            } else {
                image.draw(in: targetRect)
            }
        }

        static func applyIcon(image: NSImage, to folderURL: URL) {
            NSWorkspace.shared.setIcon(image, forFile: folderURL.path, options: [])
        }
    }

    struct VisualEffectView: NSViewRepresentable {
        let material: NSVisualEffectView.Material

        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.blendingMode = .behindWindow
            view.state = .active
            view.material = material
            return view
        }
        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
    }

    enum IconData {
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
                        "paperplane", "paperplane.fill", "antenna.radiowaves.left.and.right",
                        "wifi",
                    ]),
                IconCategory(
                    name: "Devices",
                    symbols: [
                        "display", "laptopcomputer", "iphone", "ipad", "applewatch",
                        "applewatch.watchface",
                        "airpods", "airpodspro", "homepod", "appletv", "gamecontroller",
                        "headphones",
                        "speaker.wave.2", "keyboard", "magicmouse", "printer", "scanner",
                    ]),
                IconCategory(
                    name: "Objects",
                    symbols: [
                        "star", "star.fill", "heart", "heart.fill", "flag", "flag.fill", "bolt",
                        "bolt.fill", "bell", "bell.fill", "camera", "camera.fill", "folder",
                        "folder.fill",
                        "gearshape", "gearshape.fill", "leaf", "leaf.fill", "umbrella",
                        "umbrella.fill",
                        "cloud", "cloud.fill", "sun.max", "sun.max.fill", "moon", "moon.fill",
                        "trash",
                        "trash.fill", "pencil", "link", "briefcase", "archivebox", "calendar",
                        "clock",
                        "plus.app", "shield", "lock", "lock.fill", "lock.open", "lock.open.fill",
                        "key",
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
                        "sun.max", "moon", "cloud", "cloud.rain", "snow", "wind", "tornado",
                        "hurricane",
                        "bolt", "thermometer.sun", "thermometer.snowflake", "drop", "flame", "tree",
                    ]),
                IconCategory(
                    name: "All Symbols",
                    symbols: [
                        "star", "heart", "bell", "flag", "bolt", "camera", "folder", "gearshape",
                        "leaf",
                        "umbrella", "cloud", "sun.max", "house", "magnifyingglass", "envelope",
                        "phone",
                        "paperplane", "archivebox", "briefcase", "calendar", "clock", "message",
                        "video",
                        "mic", "music.note", "photo", "map", "location", "shield", "lock",
                        "lock.open", "key", "cart", "bag", "creditcard", "gift", "gamecontroller",
                        "headphones", "speaker.wave.2", "display", "laptopcomputer", "iphone",
                        "applewatch.watchface", "trash", "pencil", "link", "plus", "minus",
                        "checkmark",
                        "xmark", "info.circle", "questionmark.circle", "exclamationmark.triangle",
                        "arrow.up", "arrow.down", "arrow.left", "arrow.right",
                        "square.and.arrow.up",
                        "square.and.arrow.down", "pencil.tip", "lasso", "folder.badge.plus",
                    ]),
            ]

            static func symbols(for categoryName: String) -> [String] {
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
    }

    #Preview {
        ContentView()
    }
#endif
