import AppKit

/// Persists applied folder icons as a PNG plus a JSON settings sidecar in
/// `~/Library/Application Support/FolderIcon/History/`.
@Observable
@MainActor
final class HistoryStore {
    struct Entry: Identifiable {
        let id: String
        let date: Date
        let image: NSImage
        let snapshot: IconSnapshot?
    }

    private struct StoredEntry: Sendable {
        let id: String
        let date: Date
        let imageData: Data
        let snapshotData: Data?
    }

    static let defaultMaxEntries = 100

    private(set) var entries: [Entry] = []
    private(set) var lastError: String?

    private let directory: URL
    private let maxEntries: Int

    init(directory: URL? = nil, maxEntries: Int = 100) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appendingPathComponent(
                "FolderIcon/History", isDirectory: true)
        }
        self.maxEntries = max(1, maxEntries)

        Task { [weak self] in
            await self?.load()
        }
    }

    @discardableResult
    func add(image: NSImage, snapshot: IconSnapshot) async -> Bool {
        guard let imageData = image.pngData else {
            lastError = "Could not encode the history image"
            return false
        }
        guard let snapshotData = try? JSONEncoder().encode(snapshot) else {
            lastError = "Could not encode the history settings"
            return false
        }

        let date = Date()
        let id = "\(date.timeIntervalSince1970)-\(UUID().uuidString)"
        let directory = directory
        let maxEntries = maxEntries

        do {
            let removedIDs = try await Task.detached(priority: .utility) {
                try Self.persist(
                    id: id,
                    imageData: imageData,
                    snapshotData: snapshotData,
                    directory: directory,
                    maxEntries: maxEntries)
            }.value

            entries.removeAll { removedIDs.contains($0.id) || $0.id == id }
            entries.insert(
                Entry(id: id, date: date, image: image, snapshot: snapshot), at: 0)
            entries = Array(entries.prefix(maxEntries))
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func delete(_ entry: Entry) async -> Bool {
        let directory = directory
        do {
            try await Task.detached(priority: .utility) {
                try Self.deleteFiles(for: entry.id, in: directory)
            }.value
            entries.removeAll { $0.id == entry.id }
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func load() async {
        let directory = directory
        let maxEntries = maxEntries

        do {
            let storedEntries = try await Task.detached(priority: .utility) {
                try Self.loadStoredEntries(from: directory, maxEntries: maxEntries)
            }.value
            let loadedEntries = storedEntries.compactMap { stored -> Entry? in
                guard let image = NSImage(data: stored.imageData) else { return nil }
                let snapshot = stored.snapshotData.flatMap {
                    try? JSONDecoder().decode(IconSnapshot.self, from: $0)
                }
                return Entry(
                    id: stored.id,
                    date: stored.date,
                    image: image,
                    snapshot: snapshot)
            }

            var byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
            for entry in loadedEntries where byID[entry.id] == nil {
                byID[entry.id] = entry
            }
            entries = Array(byID.values)
                .sorted { $0.date > $1.date }
                .prefix(maxEntries)
                .map { $0 }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    nonisolated private static func persist(
        id: String,
        imageData: Data,
        snapshotData: Data,
        directory: URL,
        maxEntries: Int
    ) throws -> Set<String> {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directory, withIntermediateDirectories: true)

        let imageURL = directory.appendingPathComponent("\(id).png")
        let jsonURL = directory.appendingPathComponent("\(id).json")

        do {
            try snapshotData.write(to: jsonURL, options: .atomic)
            try imageData.write(to: imageURL, options: .atomic)
        } catch {
            try? fileManager.removeItem(at: imageURL)
            try? fileManager.removeItem(at: jsonURL)
            throw error
        }

        return try pruneFiles(in: directory, keeping: maxEntries)
    }

    nonisolated private static func loadStoredEntries(
        from directory: URL, maxEntries: Int
    ) throws -> [StoredEntry] {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directory, withIntermediateDirectories: true)

        _ = try pruneFiles(in: directory, keeping: maxEntries)
        let files = try fileManager.contentsOfDirectory(atPath: directory.path)
        let imageIDs = files
            .filter { $0.hasSuffix(".png") }
            .map { ($0 as NSString).deletingPathExtension }

        return imageIDs.compactMap { id in
            let imageURL = directory.appendingPathComponent("\(id).png")
            guard let imageData = try? Data(contentsOf: imageURL) else { return nil }

            let jsonURL = directory.appendingPathComponent("\(id).json")
            let snapshotData = try? Data(contentsOf: jsonURL)
            return StoredEntry(
                id: id,
                date: date(from: id),
                imageData: imageData,
                snapshotData: snapshotData)
        }
        .sorted { $0.date > $1.date }
    }

    nonisolated private static func pruneFiles(
        in directory: URL, keeping maxEntries: Int
    ) throws -> Set<String> {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(atPath: directory.path)
        let imageIDs = files
            .filter { $0.hasSuffix(".png") }
            .map { ($0 as NSString).deletingPathExtension }
            .sorted {
                let left = date(from: $0)
                let right = date(from: $1)
                return left == right ? $0 > $1 : left > right
            }

        let removedIDs = Set(imageIDs.dropFirst(maxEntries))
        for id in removedIDs {
            try deleteFiles(for: id, in: directory)
        }

        let imageIDSet = Set(imageIDs)
        for jsonFile in files where jsonFile.hasSuffix(".json") {
            let id = (jsonFile as NSString).deletingPathExtension
            if !imageIDSet.contains(id) {
                try? fileManager.removeItem(
                    at: directory.appendingPathComponent(jsonFile))
            }
        }
        return removedIDs
    }

    nonisolated private static func deleteFiles(for id: String, in directory: URL) throws {
        let fileManager = FileManager.default
        let imageURL = directory.appendingPathComponent("\(id).png")
        let jsonURL = directory.appendingPathComponent("\(id).json")

        if fileManager.fileExists(atPath: imageURL.path) {
            try fileManager.removeItem(at: imageURL)
        }
        if fileManager.fileExists(atPath: jsonURL.path) {
            try? fileManager.removeItem(at: jsonURL)
        }
    }

    nonisolated private static func date(from id: String) -> Date {
        let timestamp = Double(id.split(separator: "-").first ?? "") ?? 0
        return Date(timeIntervalSince1970: timestamp)
    }
}
