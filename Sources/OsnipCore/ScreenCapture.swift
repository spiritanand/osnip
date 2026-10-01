import Foundation

public enum CaptureResult: Equatable, Sendable {
    case captured
    case cancelled
    case failed
}

public struct ScreenCapture: Sendable {
    public static let systemTool = URL(fileURLWithPath: "/usr/sbin/screencapture")

    public let tool: URL

    public init(tool: URL = ScreenCapture.systemTool) {
        self.tool = tool
    }

    public func captureInteractively(to destination: URL) -> CaptureResult {
        guard (try? Shell.run(tool, ["-i", "-o", "-t", "png", destination.path])) != nil else {
            return .failed
        }
        return FileManager.default.fileExists(atPath: destination.path) ? .captured : .cancelled
    }
}
