import AppKit

/// Persists every applied folder icon as a PNG (plus a JSON sidecar with the
/// originating settings) in `~/Library/Application Support/FolderIcon/History/`.
/// Filename format: `<unixTimestamp>-<uuid>` (timestamp doubles as the date).
@Observable
final class HistoryStore {
    struct Entry: Identifiable {
        let id: String  // filename base, e.g. "1700000000-<uuid>"
        let date: Date
        let image: NSImage
        let snapshot: IconSnapshot?
    }

    private(set) var entries: [Entry] = []

    private let directory: URL = {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FolderIcon/History", isDirectory: true)
    }()

    init() {
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        load()
    }

    func add(image: NSImage, snapshot: IconSnapshot) {
        let date = Date()
        let id = "\(Int(date.timeIntervalSince1970))-\(UUID().uuidString)"
        let imageURL = directory.appendingPathComponent("\(id).png")
        let jsonURL = directory.appendingPathComponent("\(id).json")

        guard let png = image.pngData else { return }

        do {
            try png.write(to: imageURL)
            let json = try JSONEncoder().encode(snapshot)
            try json.write(to: jsonURL)
            entries.insert(Entry(id: id, date: date, image: image, snapshot: snapshot), at: 0)
        } catch {
            // History is best-effort; a failed write must not break applying.
        }
    }

    func delete(_ entry: Entry) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(entry.id).png"))
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(entry.id).json"))
        entries.removeAll { $0.id == entry.id }
    }

    private func load() {
        guard
            let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return }

        let imageIDs = files.filter { $0.hasSuffix(".png") }.map { ($0 as NSString).deletingPathExtension }

        entries =
            imageIDs
            .compactMap { id -> Entry? in
                guard
                    let image = NSImage(contentsOf: directory.appendingPathComponent("\(id).png"))
                else { return nil }
                let timestamp = Double(id.split(separator: "-").first ?? "") ?? 0
                let snapshot: IconSnapshot? = {
                    let url = directory.appendingPathComponent("\(id).json")
                    guard
                        let data = try? Data(contentsOf: url),
                        let decoded = try? JSONDecoder().decode(IconSnapshot.self, from: data)
                    else { return nil }
                    return decoded
                }()
                return Entry(
                    id: id, date: Date(timeIntervalSince1970: timestamp), image: image,
                    snapshot: snapshot)
            }
            .sorted { $0.date > $1.date }
    }
}
