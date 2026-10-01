import Foundation

enum ToolLocator {
    static let fallbackDirectories = ["/opt/homebrew/bin", "/usr/local/bin"]

    static func locate(
        _ name: String,
        searchPath: String = ProcessInfo.processInfo.environment["PATH"] ?? ""
    ) -> URL? {
        let pathDirectories = searchPath.split(separator: ":").map(String.init)
        return (pathDirectories + fallbackDirectories)
            .map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
            .first(where: isExecutableRegularFile)
    }

    private static func isExecutableRegularFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
            && FileManager.default.isExecutableFile(atPath: url.path)
    }
}
