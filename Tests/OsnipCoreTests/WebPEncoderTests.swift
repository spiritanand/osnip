import CoreGraphics
import Foundation
import Testing
@testable import OsnipCore

struct WebPEncoderTests {
    let directory: URL

    init() throws {
        directory = try Fixture.temporaryDirectory()
    }

    private func byteCountsOfEveryCandidate(_ encoder: WebPEncoder, source: URL) throws -> [Int?] {
        let sourceWidth = try #require(ImageFile.pixelSize(of: source)).width
        return try Candidate.inPreferenceOrder.enumerated().map { index, candidate in
            let output = directory.appendingPathComponent("alone-\(index).webp")
            let arguments = encoder.arguments(for: candidate, source: source, sourcePixelWidth: sourceWidth, output: output)
            return try Shell.run(encoder.cwebp, arguments).succeeded ? try ImageFile.byteCount(of: output) : nil
        }
    }

    private func expectEveryStartedProcessExited(_ report: WebPEncoder.RaceReport) {
        #expect(report.startedProcesses.allSatisfy { !$0.isRunning })
    }

    @Test func aFlatCaptureResolvesToFullResolutionLossless() throws {
        let source = directory.appendingPathComponent("flat.png")
        try Fixture.flatInterface(width: 800, height: 600, at: source)
        let encoder = WebPEncoder(cwebp: try Fixture.cwebp())

        let report = encoder.race(source, in: directory)

        let winner = try #require(report.winner)
        #expect(winner.url.lastPathComponent == "candidate-0.webp")
        #expect(winner.byteCount <= WebPEncoder.defaultBudgetBytes)
        #expect(winner.byteCount == (try ImageFile.byteCount(of: winner.url)))
        #expect(try Fixture.isWebP(winner.url))
        #expect(ImageFile.pixelSize(of: winner.url)?.width == 800)
        #expect(ImageFile.pixelSize(of: winner.url)?.height == 600)
        expectEveryStartedProcessExited(report)
    }

    @Test func aCaptureWithTransparentCornersKeepsThem() throws {
        let source = directory.appendingPathComponent("window.png")
        try Fixture.transparentCorners(width: 320, height: 240, at: source)

        let winner = try #require(WebPEncoder(cwebp: try Fixture.cwebp()).race(source, in: directory).winner)

        #expect(try Fixture.storedAlpha(of: winner.url, x: 0, y: 0) == 0)
        #expect(try Fixture.storedAlpha(of: winner.url, x: 160, y: 120) == 255)
    }

    @Test func aOnePixelCaptureStillEncodes() throws {
        let source = directory.appendingPathComponent("dot.png")
        try Fixture.solid(RGB(red: 10, green: 20, blue: 30), colorSpaceName: CGColorSpace.sRGB, width: 1, height: 1, at: source)

        let encoder = WebPEncoder(cwebp: try Fixture.cwebp())

        let report = encoder.race(source, in: directory)

        for halfSize in Candidate.inPreferenceOrder.filter({ $0.scale == .half }) {
            let arguments = encoder.arguments(for: halfSize, source: source, sourcePixelWidth: 1, output: source)
            let resize = try #require(arguments.firstIndex(of: "-resize"))
            #expect(Array(arguments[resize...].prefix(3)) == ["-resize", "1", "0"])
        }
        #expect(try byteCountsOfEveryCandidate(encoder, source: source).allSatisfy { $0 != nil })
        let winner = try #require(report.winner)
        #expect(try Fixture.isWebP(winner.url))
        #expect(ImageFile.pixelSize(of: winner.url)?.width == 1)
        #expect(ImageFile.pixelSize(of: winner.url)?.height == 1)
        expectEveryStartedProcessExited(report)
    }

    @Test func aNoisyCaptureResolvesToTheCandidateTheRuleNames() throws {
        let source = directory.appendingPathComponent("noise.png")
        try Fixture.noise(width: 600, height: 400, at: source)
        let encoder = WebPEncoder(cwebp: try Fixture.cwebp())

        let report = encoder.race(source, in: directory)

        let byteCounts = try byteCountsOfEveryCandidate(encoder, source: source)
        let expected = try #require(CandidateSelection.winner(among: byteCounts, budgetBytes: encoder.budgetBytes))
        let winner = try #require(report.winner)
        #expect(try #require(byteCounts[0]) > encoder.budgetBytes)
        #expect(winner.url.lastPathComponent == "candidate-\(expected.index).webp")
        #expect(winner.byteCount == expected.byteCount)
        #expect(try Fixture.isWebP(winner.url))
        expectEveryStartedProcessExited(report)
    }

    @Test func anImpossibleBudgetShipsTheSmallestCandidate() throws {
        let source = directory.appendingPathComponent("flat.png")
        try Fixture.flatInterface(width: 320, height: 240, at: source)
        let encoder = WebPEncoder(cwebp: try Fixture.cwebp(), budgetBytes: 10)

        let report = encoder.race(source, in: directory)

        let byteCounts = try byteCountsOfEveryCandidate(encoder, source: source)
        let expected = try #require(CandidateSelection.winner(among: byteCounts, budgetBytes: 10))
        #expect(report.winner?.url.lastPathComponent == "candidate-\(expected.index).webp")
        #expect(report.winner?.byteCount == byteCounts.compactMap { $0 }.min())
        expectEveryStartedProcessExited(report)
    }

    @Test func aMissingEncoderThrows() throws {
        let source = directory.appendingPathComponent("flat.png")
        try Fixture.flatInterface(width: 64, height: 48, at: source)
        let encoder = WebPEncoder(cwebp: directory.appendingPathComponent("no-such-cwebp"))

        #expect(encoder.race(source, in: directory).startedProcesses.isEmpty)
        #expect(throws: OptimizationError.noCandidateSucceeded) { try encoder.encode(source, in: directory) }
    }

    @Test func anUnreadableSourceThrows() throws {
        let source = directory.appendingPathComponent("not-an-image.png")
        try Data("not an image".utf8).write(to: source)
        let encoder = WebPEncoder(cwebp: try Fixture.cwebp())

        #expect(throws: OptimizationError.noCandidateSucceeded) { try encoder.encode(source, in: directory) }
    }

    @Test func losingEncodersAreStoppedAndReapedOnceAWinnerIsKnown() throws {
        let source = directory.appendingPathComponent("flat.png")
        try Fixture.flatInterface(width: 64, height: 48, at: source)
        let slowLosers = try Fixture.executableScript(
            """
            for argument in "$@"; do output="$argument"; done
            case "$*" in
              *-resize*|*-size*) exec sleep 30 ;;
              *) printf winner > "$output" ;;
            esac
            """,
            named: "cwebp-stand-in", in: directory
        )
        let encoder = WebPEncoder(cwebp: slowLosers)
        let started = Date()

        let report = encoder.race(source, in: directory)

        #expect(report.winner?.url.lastPathComponent == "candidate-0.webp")
        #expect(report.startedProcesses.count == 4)
        expectEveryStartedProcessExited(report)
        #expect(Date().timeIntervalSince(started) < 10)
    }
}
