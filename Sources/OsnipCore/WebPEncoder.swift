import Foundation

public enum OptimizationError: Error, Equatable {
    case encoderNotFound
    case colorNormalizationFailed
    case noCandidateSucceeded
}

public struct EncodedImage: Equatable, Sendable {
    public let url: URL
    public let byteCount: Int
}

public struct Candidate: Equatable, Sendable {
    public enum Scale: Sendable { case full, half }
    public enum Mode: Sendable { case lossless, lossy }

    public let scale: Scale
    public let mode: Mode

    public static let inPreferenceOrder = [
        Candidate(scale: .full, mode: .lossless),
        Candidate(scale: .full, mode: .lossy),
        Candidate(scale: .half, mode: .lossless),
        Candidate(scale: .half, mode: .lossy),
    ]
}

public enum CandidateSelection {
    public static func winner(among byteCounts: [Int?], budgetBytes: Int) -> (index: Int, byteCount: Int)? {
        let successes = byteCounts.enumerated().compactMap { index, byteCount in
            byteCount.map { (index: index, byteCount: $0) }
        }
        if let firstFitting = successes.first(where: { $0.byteCount <= budgetBytes }) {
            return firstFitting
        }
        return successes.min { ($0.byteCount, $0.index) < ($1.byteCount, $1.index) }
    }
}

public struct WebPEncoder {
    public static let defaultBudgetBytes = 100_000
    static let lossyTargetFraction = 0.92
    static let lossyQualityFloor = 60

    public let cwebp: URL
    public let budgetBytes: Int

    public init(cwebp: URL, budgetBytes: Int = WebPEncoder.defaultBudgetBytes) {
        self.cwebp = cwebp
        self.budgetBytes = budgetBytes
    }

    public func encode(_ source: URL, in workDirectory: URL) throws -> EncodedImage {
        guard let winner = race(source, in: workDirectory).winner else {
            throw OptimizationError.noCandidateSucceeded
        }
        return winner
    }

    struct RaceReport {
        let winner: EncodedImage?
        let startedProcesses: [Process]
    }

    func race(_ source: URL, in workDirectory: URL) -> RaceReport {
        guard let sourcePixelSize = ImageFile.pixelSize(of: source) else {
            return RaceReport(winner: nil, startedProcesses: [])
        }
        let runs = Candidate.inPreferenceOrder.enumerated().map { index, candidate in
            let output = workDirectory.appendingPathComponent("candidate-\(index).webp")
            let arguments = arguments(for: candidate, source: source, sourcePixelWidth: sourcePixelSize.width, output: output)
            return CandidateRun(output: output, process: try? Shell.start(cwebp, arguments))
        }
        defer { runs.forEach { $0.stopAndReap() } }

        var byteCounts: [Int?] = []
        for run in runs {
            let byteCount = run.waitForByteCount()
            byteCounts.append(byteCount)
            if let byteCount, byteCount <= budgetBytes { break }
        }
        let winner = CandidateSelection.winner(among: byteCounts, budgetBytes: budgetBytes).map {
            EncodedImage(url: runs[$0.index].output, byteCount: $0.byteCount)
        }
        return RaceReport(winner: winner, startedProcesses: runs.compactMap(\.process))
    }

    func arguments(for candidate: Candidate, source: URL, sourcePixelWidth: Int, output: URL) -> [String] {
        var arguments = ["-quiet", "-mt"]
        switch candidate.mode {
        case .lossless:
            arguments += ["-lossless", "-z", "6"]
        case .lossy:
            let targetBytes = Int(Double(budgetBytes) * Self.lossyTargetFraction)
            arguments += ["-size", String(targetBytes), "-qrange", String(Self.lossyQualityFloor), "100", "-pass", "6", "-m", "4", "-sharp_yuv"]
        }
        if candidate.scale == .half {
            arguments += ["-resize", String(max(1, sourcePixelWidth / 2)), "0"]
        }
        return arguments + [source.path, "-o", output.path]
    }
}

private struct CandidateRun {
    let output: URL
    let process: Process?

    func waitForByteCount() -> Int? {
        guard let process else { return nil }
        process.waitUntilExit()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else { return nil }
        return try? ImageFile.byteCount(of: output)
    }

    func stopAndReap() {
        guard let process else { return }
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
    }
}
