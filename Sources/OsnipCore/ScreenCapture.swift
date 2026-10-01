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
        guard let result = try? Shell.run(tool, ["-i", "-o", "-t", "png", destination.path]) else {
            return .failed
        }
        if ImageFile.isCompletePNG(destination) { return .captured }
        let wroteNothing = !FileManager.default.fileExists(atPath: destination.path)
        let matchesEscapeSignature = wroteNothing && result.standardError.isEmpty && result.exitedNormally
        return matchesEscapeSignature ? .cancelled : .failed
    }
}
