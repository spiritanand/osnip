import Foundation

public struct Snip {
    var capture: (URL) -> CaptureResult
    var locateEncoder: () -> URL?
    var normalizer: ColorNormalizer
    var budgetBytes: Int
    var store: CaptureStore
    var clipboard: Clipboard
    var lockFile: URL
    var screenRecordingIsGranted: () -> Bool
    var promptForScreenRecording: () -> Void

    public static func live() -> Snip {
        Snip(
            capture: { ScreenCapture().captureInteractively(to: $0) },
            locateEncoder: { ToolLocator.locate("cwebp") },
            normalizer: ColorNormalizer(),
            budgetBytes: WebPEncoder.defaultBudgetBytes,
            store: CaptureStore(),
            clipboard: Clipboard(),
            lockFile: RunLock.defaultFile,
            screenRecordingIsGranted: ScreenRecordingPermission.isGranted,
            promptForScreenRecording: ScreenRecordingPermission.requestAndOpenSettings
        )
    }

    public func run() -> Outcome {
        switch RunLock.acquire(at: lockFile) {
        case .heldByAnotherRun:
            return .busy
        case .unavailable:
            return .captureFailed
        case let .acquired(lock):
            return withExtendedLifetime(lock) { runHoldingLock() }
        }
    }

    private func runHoldingLock() -> Outcome {
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
        guard let originalBytes = ImageFile.byteCount(of: original) else { return .captureFailed }
        guard let optimized = optimize(original, in: workDirectory) else {
            return publish(original, as: .png) ? .copiedOriginal : .clipboardFailed
        }
        guard publish(optimized.url, as: .webP) else { return .clipboardFailed }
        return .copied(originalBytes: originalBytes, optimizedBytes: optimized.byteCount)
    }

    private func optimize(_ original: URL, in workDirectory: URL) -> EncodedImage? {
        guard let cwebp = locateEncoder() else { return nil }
        let normalized = workDirectory.appendingPathComponent("srgb.png")
        guard normalizer.makeSRGBCopy(of: original, at: normalized) else { return nil }
        return WebPEncoder(cwebp: cwebp, budgetBytes: budgetBytes).race(normalized, in: workDirectory).winner
    }

    private func publish(_ file: URL, as imageType: Clipboard.ImageType) -> Bool {
        guard let stored = try? store.add(file, fileExtension: imageType.fileExtension),
              clipboard.publish(stored, as: imageType)
        else { return false }
        store.prune(keeping: stored)
        return true
    }
}
