import Foundation

public struct Snip {
    public var capture: (URL) -> CaptureResult
    public var locateEncoder: () -> URL?
    public var normalizer: ColorNormalizer
    public var budgetBytes: Int
    public var store: CaptureStore
    public var clipboard: Clipboard
    public var screenRecordingIsGranted: () -> Bool
    public var promptForScreenRecording: () -> Void

    public init(
        capture: @escaping (URL) -> CaptureResult,
        locateEncoder: @escaping () -> URL?,
        normalizer: ColorNormalizer,
        budgetBytes: Int,
        store: CaptureStore,
        clipboard: Clipboard,
        screenRecordingIsGranted: @escaping () -> Bool,
        promptForScreenRecording: @escaping () -> Void
    ) {
        self.capture = capture
        self.locateEncoder = locateEncoder
        self.normalizer = normalizer
        self.budgetBytes = budgetBytes
        self.store = store
        self.clipboard = clipboard
        self.screenRecordingIsGranted = screenRecordingIsGranted
        self.promptForScreenRecording = promptForScreenRecording
    }

    public static func live() -> Snip {
        Snip(
            capture: { ScreenCapture().captureInteractively(to: $0) },
            locateEncoder: { ToolLocator.locate("cwebp") },
            normalizer: ColorNormalizer(),
            budgetBytes: WebPEncoder.defaultBudgetBytes,
            store: CaptureStore(),
            clipboard: Clipboard(),
            screenRecordingIsGranted: ScreenRecordingPermission.isGranted,
            promptForScreenRecording: ScreenRecordingPermission.requestAndOpenSettings
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
            guard screenRecordingIsGranted() else {
                promptForScreenRecording()
                return .screenRecordingDenied
            }
            return .captureFailed
        case .captured:
            return publishCapture(original, workDirectory: workDirectory)
        }
    }

    private func publishCapture(_ original: URL, workDirectory: URL) -> Outcome {
        guard let originalBytes = try? ImageFile.byteCount(of: original) else { return .captureFailed }
        guard let optimized = try? optimize(original, in: workDirectory),
              publish(optimized.url, fileExtension: "webp", as: .webP)
        else { return .clipboardFailed }
        return .copied(originalBytes: originalBytes, optimizedBytes: optimized.byteCount)
    }

    private func optimize(_ original: URL, in workDirectory: URL) throws -> EncodedImage {
        guard let cwebp = locateEncoder() else { throw OptimizationError.encoderNotFound }
        let normalized = workDirectory.appendingPathComponent("srgb.png")
        try normalizer.makeSRGBCopy(of: original, at: normalized)
        return try WebPEncoder(cwebp: cwebp, budgetBytes: budgetBytes).encode(normalized, in: workDirectory)
    }

    private func publish(_ file: URL, fileExtension: String, as imageType: Clipboard.ImageType) -> Bool {
        guard let stored = try? store.add(file, fileExtension: fileExtension),
              (try? clipboard.publish(stored, as: imageType)) != nil
        else { return false }
        store.prune(keeping: stored)
        return true
    }
}
