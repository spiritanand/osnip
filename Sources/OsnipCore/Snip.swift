import Foundation

public struct Snip {
    public var capture: (URL) -> CaptureResult
    public var locateEncoder: () -> URL?
    public var normalizer: ColorNormalizer
    public var budgetBytes: Int
    public var outputDirectory: URL
    public var clipboard: Clipboard

    public init(
        capture: @escaping (URL) -> CaptureResult,
        locateEncoder: @escaping () -> URL?,
        normalizer: ColorNormalizer,
        budgetBytes: Int,
        outputDirectory: URL,
        clipboard: Clipboard
    ) {
        self.capture = capture
        self.locateEncoder = locateEncoder
        self.normalizer = normalizer
        self.budgetBytes = budgetBytes
        self.outputDirectory = outputDirectory
        self.clipboard = clipboard
    }

    public static func live() -> Snip {
        Snip(
            capture: { ScreenCapture().captureInteractively(to: $0) },
            locateEncoder: { ToolLocator.locate("cwebp") },
            normalizer: ColorNormalizer(),
            budgetBytes: WebPEncoder.defaultBudgetBytes,
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
            return publishCapture(original, workDirectory: workDirectory)
        }
    }

    private func publishCapture(_ original: URL, workDirectory: URL) -> Outcome {
        guard let originalBytes = try? ImageFile.byteCount(of: original) else { return .captureFailed }
        guard let optimized = try? optimize(original, in: workDirectory),
              let published = try? moveIntoOutputDirectory(optimized.url),
              (try? clipboard.publish(published, as: .webP)) != nil
        else { return .clipboardFailed }
        return .copied(originalBytes: originalBytes, optimizedBytes: optimized.byteCount)
    }

    private func optimize(_ original: URL, in workDirectory: URL) throws -> EncodedImage {
        guard let cwebp = locateEncoder() else { throw OptimizationError.encoderNotFound }
        let normalized = workDirectory.appendingPathComponent("srgb.png")
        try normalizer.makeSRGBCopy(of: original, at: normalized)
        return try WebPEncoder(cwebp: cwebp, budgetBytes: budgetBytes).encode(normalized, in: workDirectory)
    }

    private func moveIntoOutputDirectory(_ file: URL) throws -> URL {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let destination = outputDirectory.appendingPathComponent("osnip-\(UUID().uuidString).webp")
        try FileManager.default.moveItem(at: file, to: destination)
        return destination
    }
}
