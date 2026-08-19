import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct IconTabView: View {
    @Bindable var state: AppState

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
        SectionCard(title: "Emoji", subtitle: "Paste any emoji") {
            TextField("e.g. 🚀", text: $state.selectedEmoji)
                .textFieldStyle(.plain)
                .font(.system(size: 40))
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
        }
    }

    private var customView: some View {
        SectionCard(title: "Custom Image", subtitle: "Drop any logo or image") {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundColor(.gray.opacity(0.5))
                        .frame(height: 110)

                    if let img = state.customImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 76, height: 76)
                    } else {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleImageDrop(providers: providers)
                }

                if state.customImage != nil {
                    Button(action: {
                        state.customImage = nil
                        state.selectedIconType = .symbols
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
        SFSymbolsLibrary.symbols(for: state.selectedCategory).filter {
            state.searchText.isEmpty || $0.lowercased().contains(state.searchText.lowercased())
        }
    }

    private var searchBarView: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search or enter name", text: $state.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .onChange(of: state.searchText) { _, newValue in
                state.selectedSymbol = newValue
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

            Button(action: { state.selectedSymbol = "" }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(state.selectedSymbol.isEmpty ? .gray.opacity(0.4) : .red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .help("Clear current symbol")
            }
            .buttonStyle(.plain)
            .disabled(state.selectedSymbol.isEmpty)
        }
    }

    @ViewBuilder
    private func categoryButton(for cat: IconCategory) -> some View {
        Button(action: { state.selectedCategory = cat.name }) {
            Text(cat.name)
                .font(
                    .system(
                        size: 11,
                        weight: state.selectedCategory == cat.name ? .bold : .regular))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    state.selectedCategory == cat.name
                        ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                .cornerRadius(6)
                .foregroundColor(state.selectedCategory == cat.name ? .blue : .primary)
        }
        .buttonStyle(.plain)
    }

    private var symbolsView: some View {
        VStack(spacing: 12) {
            SectionCard(title: "Categories") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SFSymbolsLibrary.categories) { cat in
                            categoryButton(for: cat)
                        }
                    }
                }
            }

            SectionCard(title: "Symbols", subtitle: categorySubtitle) {
                VStack(spacing: 12) {
                    searchBarView

                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12
                        ) {
                            ForEach(filteredSymbols, id: \.self) { sym in
                                Button(action: { state.selectedSymbol = sym }) {
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

    private var categorySubtitle: String {
        "\(filteredSymbols.count) symbols"
    }

    private func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, let img = NSImage(contentsOf: url) else { return }
            DispatchQueue.main.async {
                state.customImage = img
            }
        }
        return true
    }
}
