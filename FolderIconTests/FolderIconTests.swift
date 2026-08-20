import AppKit
import XCTest
@testable import FolderIcon

@MainActor
final class FolderIconTests: XCTestCase {
    func testDefaultOpacityIsOneHundredPercent() {
        XCTAssertEqual(AppState().tintOpacity, 1.0)
    }

    func testAllSymbolsGridIsCompleteAndUnique() {
        let symbols = SFSymbolsLibrary.symbols(for: "All Symbols")

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
