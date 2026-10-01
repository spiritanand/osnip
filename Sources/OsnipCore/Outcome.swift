public enum Outcome: Equatable, Sendable {
    case copied(originalBytes: Int, optimizedBytes: Int)
    case copiedOriginal
    case cancelled
    case busy
    case screenRecordingDenied
    case captureFailed
    case clipboardFailed

    public var hudLine: String? {
        switch self {
        case let .copied(originalBytes, optimizedBytes):
            let optimized = ByteCount.formatted(optimizedBytes)
            let savedBytes = originalBytes - optimizedBytes
            guard originalBytes > 0, savedBytes * 100 >= originalBytes else { return "Copied · \(optimized)" }
            let savedPercent = Int((Double(savedBytes) / Double(originalBytes) * 100).rounded())
            return "Copied · \(ByteCount.formatted(originalBytes)) → \(optimized) (−\(savedPercent)%)"
        case .copiedOriginal:
            return "Copied original · Optimization failed"
        case .cancelled, .busy:
            return nil
        case .screenRecordingDenied:
            return "Allow Screen Recording for Raycast"
        case .captureFailed:
            return "Couldn't capture"
        case .clipboardFailed:
            return "Couldn't copy"
        }
    }

    public var exitCode: Int32 {
        switch self {
        case .copied, .copiedOriginal, .cancelled, .busy:
            return 0
        case .screenRecordingDenied, .captureFailed, .clipboardFailed:
            return 1
        }
    }
}
