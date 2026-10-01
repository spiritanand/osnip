import Foundation

struct CaptureStore {
    static let defaultKeptCaptures = 50
    static let namePrefix = "osnip-"

    var directory = CaptureStore.defaultDirectory
    var keptCaptures = CaptureStore.defaultKeptCaptures

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("osnip", isDirectory: true)
    }

    func add(_ file: URL, fileExtension: String, capturedAt date: Date = Date()) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = unusedURL(stem: Self.namePrefix + Self.timestamp(date), fileExtension: fileExtension)
        try FileManager.default.moveItem(at: file, to: destination)
        return destination
    }

    func prune(keeping added: URL) {
        let fileFacts: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(fileFacts)
        ) else { return }
        let otherCapturesNewestFirst = entries
            .filter { $0.lastPathComponent.hasPrefix(Self.namePrefix) && $0.lastPathComponent != added.lastPathComponent }
            .compactMap { entry -> (url: URL, modified: Date)? in
                guard let facts = try? entry.resourceValues(forKeys: fileFacts), facts.isRegularFile == true else { return nil }
                return (entry, facts.contentModificationDate ?? .distantPast)
            }
            .sorted { ($0.modified, $0.url.lastPathComponent) > ($1.modified, $1.url.lastPathComponent) }
        for stale in otherCapturesNewestFirst.dropFirst(max(0, keptCaptures - 1)) {
            try? FileManager.default.removeItem(at: stale.url)
        }
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter.string(from: date)
    }

    private func unusedURL(stem: String, fileExtension: String) -> URL {
        var attempt = 1
        while true {
            let name = attempt == 1 ? stem : "\(stem)-\(attempt)"
            let url = directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
            if !FileManager.default.fileExists(atPath: url.path) { return url }
            attempt += 1
        }
    }
}
