import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var state = AppState()
    @State private var previewImage: NSImage?
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var statusDismissTask: Task<Void, Never>?
    @State private var isDropTargeted = false
    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 0) {
            leftPanel
                .frame(width: 320)

            Divider()

            rightPanel
                .frame(maxWidth: .infinity)
        }
        .frame(width: 880, height: 760)
        .background(Color(red: 235 / 255, green: 236 / 255, blue: 237 / 255))
        .background(VisualEffectView(material: .underWindowBackground).ignoresSafeArea())
        .task(id: state.renderConfiguration) {
            await updatePreview()
        }
    }

    // MARK: - Left Panel (Drop Zone & Preview)

    private var leftPanel: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isDropTargeted
                        ? Color.blue.opacity(0.08) : Color.secondary.opacity(0.05))

            if state.folderURLs.isEmpty {
                emptyState
            } else {
                previewState
            }

            if !state.folderURLs.isEmpty {
                Button(action: { state.folderURLs.removeAll() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(4)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .buttonStyle(.plain)
                .padding(12)
                .help("Remove all folders")
            }
        }
        .padding(16)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("Drop folders here")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("One or more at once")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            if let preview = previewImage {
                Image(nsImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 240)
            }

            Spacer(minLength: 12)

            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text(state.folderURLs[0].lastPathComponent)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    if state.folderURLs.count > 1 {
                        Text("+ \(state.folderURLs.count - 1) more")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Text(statusMessage ?? " ")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(statusIsError ? .red : .green)
                    .frame(height: 16)

                footerButtons
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Footer Buttons

    private var footerButtons: some View {
        HStack(spacing: 10) {
            Button(action: {
                Task { await resetIcons() }
            }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.15))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .help("Restore default folder icons")

            Button(action: {
                Task { await applyChanges() }
            }) {
                HStack {
                    Image(
                        systemName: state.folderURLs.isEmpty
                            ? "lock.fill" : "lock.open.fill")
                    Text(colorizeLabel)
                }
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.65 : 1)
        }
    }

    private var colorizeLabel: String {
        let count = state.folderURLs.count
        return count == 1 ? "Colorize" : "Colorize \(count)"
    }

    // MARK: - Right Panel (Controls)

    private var rightPanel: some View {
        VStack(spacing: 0) {
            appBar
                .padding(.top, 16)
                .padding(.bottom, 12)
                .padding(.horizontal, 16)

            tabContent
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }

    private var appBar: some View {
        HStack {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .cornerRadius(6)
            Text("FolderIcon")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            tabBar
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ContentTab.allCases, id: \.self) { tab in
                let isActive = state.selectedTab == tab
                Button(action: { state.selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: isActive ? .bold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(isActive ? Color.white : Color.clear)
                        .cornerRadius(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(2)
                .focusable(false)
            }
        }
        .frame(width: 320)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch state.selectedTab {
        case .color:
            ColorTabView(state: state)
        case .icon:
            IconTabView(state: state)
        case .details:
            DetailsTabView(state: state)
        case .history:
            HistoryTabView(state: state) { snapshot in
                state.restore(from: snapshot)
                // Drop the cached preview: it still shows the pre-restore render
                // (the debounced re-render hasn't run yet), so force a fresh
                // render in applyChanges via `previewImage ?? makeImage()`.
                previewImage = nil
                Task { await applyChanges(recordHistory: false) }
            }
        }
    }

    // MARK: - Preview Rendering

    /// Debounced: `task(id:)` cancels the previous run whenever any rendering
    /// input changes, so fast slider drags trigger at most one render.
    private func updatePreview() async {
        guard !state.folderURLs.isEmpty else {
            previewImage = nil
            return
        }
        try? await Task.sleep(for: .milliseconds(100))
        guard !Task.isCancelled else { return }
        previewImage = makeImage()
    }

    private var folderTint: FolderTint {
        switch state.tintMode {
        case .solid:
            return .solid(state.folderColor.nsColor)
        case .gradient:
            return .gradient(
                start: state.gradientStart.nsColor,
                end: state.gradientEnd.nsColor,
                angle: state.gradientAngle)
        }
    }

    private func makeImage() -> NSImage? {
        if state.selectedIconType == .custom, let image = state.customImage {
            return FolderProcessor.createCustomFolder(
                tint: folderTint,
                symbolName: "",
                symbolSize: state.symbolSize,
                symbolColor: state.iconColor.nsColor,
                style: state.iconStyle,
                tintOpacity: state.tintOpacity,
                customImage: image)
        }

        let symbol = state.selectedIconType == .emojis ? state.selectedEmoji : state.selectedSymbol
        return FolderProcessor.createCustomFolder(
            tint: folderTint,
            symbolName: symbol,
            symbolSize: state.symbolSize,
            symbolColor: state.iconColor.nsColor,
            style: state.iconStyle,
            tintOpacity: state.tintOpacity,
            isEmoji: state.selectedIconType == .emojis && !state.selectedEmoji.isEmpty)
    }

    // MARK: - Actions

    private func applyChanges(recordHistory: Bool = true) async {
        guard !isProcessing else { return }
        guard let image = previewImage ?? makeImage(), let imageData = image.pngData else {
            showStatus("Could not render the folder icon", error: true)
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let folderURLs = state.folderURLs
        let snapshot = recordHistory ? IconSnapshot(state: state) : nil
        let results = await Task.detached(priority: .userInitiated) {
            FolderProcessor.applyIcon(imageData, to: folderURLs)
        }.value
        let failed = results.filter { !$0 }.count
        let applied = results.count - failed

        var historySaved = true
        if applied > 0, let snapshot {
            historySaved = await state.history.add(image: image, snapshot: snapshot)
        }

        if applied > 0 && !historySaved {
            showStatus(
                applied == 1
                    ? "Folder updated; history was not saved"
                    : "\(applied) updated; history was not saved",
                error: true)
            return
        }

        switch (applied, failed) {
        case (0, _):
            showStatus("Failed to update folders", error: true)
        case (_, 0):
            showStatus(
                applied == 1 ? "Folder updated" : "\(applied) folders updated", error: false)
        default:
            showStatus("\(applied) updated, \(failed) failed", error: true)
        }
    }

    private func resetIcons() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        let folderURLs = state.folderURLs
        let results = await Task.detached(priority: .userInitiated) {
            folderURLs.map { url in
                do {
                    try FolderProcessor.resetIcon(for: url)
                    return true
                } catch {
                    return false
                }
            }
        }.value
        let applied = results.filter { $0 }.count
        let failed = results.count - applied

        switch (applied, failed) {
        case (0, _):
            showStatus("Failed to restore icons", error: true)
        case (_, 0):
            showStatus(
                applied == 1 ? "Folder restored" : "\(applied) folders restored", error: false)
        default:
            showStatus("\(applied) restored, \(failed) failed", error: true)
        }
    }

    private func showStatus(_ message: String, error: Bool) {
        statusDismissTask?.cancel()
        statusMessage = message
        statusIsError = error
        statusDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            statusMessage = nil
        }
    }

    // MARK: - Drag & Drop

    /// Accepts the drop optimistically; invalid items (non-folders) are
    /// filtered out asynchronously in the load completion handlers.
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard
                    let url,
                    (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                else { return }
                DispatchQueue.main.async {
                    if !state.folderURLs.contains(url) {
                        state.folderURLs.append(url)
                    }
                }
            }
        }
        return true
    }
}

#Preview {
    ContentView()
}
