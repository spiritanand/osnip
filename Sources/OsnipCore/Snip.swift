import Foundation

public struct Snip {
    public var capture: (URL) -> CaptureResult
    public var locateEncoder: () -> URL?
    public var outputDirectory: URL
    public var clipboard: Clipboard

    public init(
        capture: @escaping (URL) -> CaptureResult,
        locateEncoder: @escaping () -> URL?,
        outputDirectory: URL,
        clipboard: Clipboard
    ) {
        self.capture = capture
        self.locateEncoder = locateEncoder
        self.outputDirectory = outputDirectory
        self.clipboard = clipboard
    }

    public static func live() -> Snip {
        Snip(
            capture: { ScreenCapture().captureInteractively(to: $0) },
            locateEncoder: { ToolLocator.locate("cwebp") },
            outputDirectory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("osnip", isDirectory: true),
            clipboard: Clipboard()
        )
    }

    public func run() -> Outcome {
        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("osnip-\(UUID().uuidString)", isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)) != nil else {
            return .captureFailed
        }
        defer { try? FileManager.default.removeItem(at: workDirectory) }

        let original = workDirectory.appendingPathComponent("capture.png")
        switch capture(original) {
        case .cancelled:
            return .cancelled
        case .failed:
            return .captureFailed
        case .captured:
            return publishCapture(original)
        }
    }

    private func publishCapture(_ original: URL) -> Outcome {
        guard let originalBytes = try? ImageFile.byteCount(of: original) else { return .captureFailed }
        guard let optimized = try? encodeLossless(original),
              (try? clipboard.publish(optimized.url, as: .webP)) != nil
        else { return .clipboardFailed }
        return .copied(originalBytes: originalBytes, optimizedBytes: optimized.byteCount)
    }

    private func encodeLossless(_ original: URL) throws -> (url: URL, byteCount: Int) {
        guard let cwebp = locateEncoder() else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let output = outputDirectory.appendingPathComponent("osnip-\(UUID().uuidString).webp")
        guard try Shell.run(cwebp, ["-quiet", "-lossless", original.path, "-o", output.path]).succeeded else {
            throw CocoaError(.fileWriteUnknown)
        }
        return (output, try ImageFile.byteCount(of: output))
    }
}
