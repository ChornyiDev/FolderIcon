import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import FolderIcon

@MainActor
final class FolderIconTests: XCTestCase {
    func testDefaultOpacityIsOneHundredPercent() {
        XCTAssertEqual(AppState().tintOpacity, 1.0)
    }

    func testEmojiInputIsLimitedToFourCharacters() {
        XCTAssertEqual(IconTabView.limitedEmojiInput("ABCDE"), "ABCD")
        XCTAssertEqual(IconTabView.limitedEmojiInput("🚀⭐️🔥💡✅"), "🚀⭐️🔥💡")
    }

    func testAllSymbolsGridIsCompleteAndUnique() {
        let symbols = SFSymbolsLibrary.symbols(for: "All")

        XCTAssertEqual(symbols.count, 64)
        XCTAssertEqual(Set(symbols).count, symbols.count)
        XCTAssertEqual(symbols.count % 8, 0)
    }

    func testRestoringSymbolSynchronizesInputField() {
        let state = AppState()
        let snapshot = makeSnapshot(symbolName: "sparkles")

        state.restore(from: snapshot)

        XCTAssertEqual(state.selectedSymbol, "sparkles")
        XCTAssertEqual(state.searchText, "sparkles")
    }

    func testIconPositionTriggersPreviewAndRestoresFromHistory() {
        let state = AppState()
        let initialConfiguration = state.renderConfiguration
        state.iconOffsetX = 36
        state.iconOffsetY = -24
        XCTAssertNotEqual(state.renderConfiguration, initialConfiguration)

        let snapshot = IconSnapshot(state: state)
        let restoredState = AppState()
        restoredState.restore(from: snapshot)
        XCTAssertEqual(restoredState.iconOffsetX, 36)
        XCTAssertEqual(restoredState.iconOffsetY, -24)
    }

    func testZeroOpacityDoesNotRevealSystemBlueFolder() throws {
        let image = try XCTUnwrap(
            FolderProcessor.createCustomFolder(
                tint: .solid(.systemGreen),
                symbolName: "",
                symbolSize: 160,
                symbolColor: .black,
                style: .original,
                tintOpacity: 0))
        let representation = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let bitmap = NSBitmapImageRep(cgImage: representation)
        let center = try XCTUnwrap(
            bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))

        XCTAssertEqual(center.alphaComponent, 0, accuracy: 0.001)
    }

    func testCustomImageLoaderAcceptsPNGFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let imageURL = directory.appendingPathComponent("custom-icon.png")
        try XCTUnwrap(makeImage().pngData).write(to: imageURL)

        let image = try XCTUnwrap(IconTabView.loadThumbnail(from: imageURL))
        XCTAssertGreaterThan(image.width, 0)
        XCTAssertEqual(image.width, image.height)
    }

    func testCustomImageLoaderAcceptsSVGFile() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let imageURL = directory.appendingPathComponent("custom-icon.svg")
        let svg = """
            <svg xmlns="http://www.w3.org/2000/svg" width="32" height="16" viewBox="0 0 32 16">
              <rect width="32" height="16" rx="2" fill="#00AA66"/>
            </svg>
            """
        try Data(svg.utf8).write(to: imageURL)

        let loadedImage = await IconTabView.loadCustomImage(from: imageURL)
        let image = try XCTUnwrap(loadedImage)
        XCTAssertGreaterThanOrEqual(max(image.width, image.height), 1024)
        XCTAssertGreaterThan(image.height, 0)
        let bitmap = NSBitmapImageRep(cgImage: image)
        let center = try XCTUnwrap(
            bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))
        XCTAssertGreaterThan(center.greenComponent, 0.4)
        XCTAssertLessThan(center.redComponent, 0.2)
    }

    func testCustomImageLoaderAcceptsDroppedSVGData() async throws {
        let svg = """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
              <path fill="#00AA66" d="M0 0h24v24H0z"/>
            </svg>
            """

        let loadedImage = await IconTabView.loadCustomImage(
            from: Data(svg.utf8), typeIdentifier: UTType.svg.identifier)
        let image = try XCTUnwrap(loadedImage)

        XCTAssertGreaterThanOrEqual(max(image.width, image.height), 1024)
    }

    func testHistoryPrunesOldEntriesAndDeletesFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let history = HistoryStore(directory: directory, maxEntries: 2)
        let image = makeImage()

        for index in 0..<3 {
            let saved = await history.add(
                image: image,
                snapshot: makeSnapshot(symbolName: "star.\(index)"))
            XCTAssertTrue(saved)
        }

        XCTAssertEqual(history.entries.count, 2)
        XCTAssertEqual(try files(withExtension: "png", in: directory).count, 2)
        XCTAssertEqual(try files(withExtension: "json", in: directory).count, 2)

        let entry = try XCTUnwrap(history.entries.first)
        let deleted = await history.delete(entry)
        XCTAssertTrue(deleted)
        XCTAssertEqual(history.entries.count, 1)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("\(entry.id).png").path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("\(entry.id).json").path))
    }

    private func makeSnapshot(symbolName: String) -> IconSnapshot {
        let state = AppState()
        state.selectedIconType = .symbols
        state.selectedSymbol = symbolName
        return IconSnapshot(state: state)
    }

    private func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemGreen.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()
        return image
    }

    private func files(withExtension extensionName: String, in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == extensionName }
    }
}
