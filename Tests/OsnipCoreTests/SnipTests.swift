import AppKit
import Foundation
import Testing
@testable import OsnipCore

final class CallCounter {
    private(set) var count = 0
    func record() { count += 1 }
}

struct SnipTests {
    let directory: URL
    let storeDirectory: URL
    let lockFile: URL
    let fixture: URL
    let pasteboard: NSPasteboard
    let captureCalls = CallCounter()
    let permissionPrompts = CallCounter()

    init() throws {
        directory = try Fixture.temporaryDirectory()
        storeDirectory = directory.appendingPathComponent("store", isDirectory: true)
        lockFile = directory.appendingPathComponent("osnip.lock")
        fixture = directory.appendingPathComponent("fixture.png")
        try Fixture.flatInterface(width: 800, height: 600, at: fixture)
        pasteboard = Fixture.privatePasteboard()
        pasteboard.clearContents()
        pasteboard.setString("previous", forType: .string)
    }

    private func snip(
        capturing result: CaptureResult,
        encoder: URL? = ToolLocator.locate("cwebp"),
        normalizer: ColorNormalizer = ColorNormalizer(),
        storeDirectory: URL? = nil,
        keptCaptures: Int = CaptureStore.defaultKeptCaptures,
        budgetBytes: Int = WebPEncoder.defaultBudgetBytes,
        screenRecordingGranted: Bool = true
    ) -> Snip {
        Snip(
            capture: { [fixture, captureCalls] destination in
                captureCalls.record()
                if result == .captured { try? FileManager.default.copyItem(at: fixture, to: destination) }
                return result
            },
            locateEncoder: { encoder },
            normalizer: normalizer,
            budgetBytes: budgetBytes,
            store: CaptureStore(directory: storeDirectory ?? self.storeDirectory, keptCaptures: keptCaptures),
            clipboard: Clipboard(pasteboard: pasteboard),
            lockFile: lockFile,
            screenRecordingIsGranted: { screenRecordingGranted },
            promptForScreenRecording: { [permissionPrompts] in permissionPrompts.record() }
        )
    }

    private func storedFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)) ?? []
    }

    private func publishedFileURL() -> URL? {
        pasteboard.pasteboardItems?.first?.string(forType: .fileURL).flatMap(URL.init(string:))
    }

    @Test func aCaptureEndsUpAsAStoredWebPOnTheClipboard() throws {
        defer { pasteboard.releaseGlobally() }
        try #require(ToolLocator.locate("cwebp") != nil, "cwebp is required: brew install webp")

        let outcome = snip(capturing: .captured).run()

        guard case let .copied(originalBytes, optimizedBytes) = outcome else {
            Issue.record("expected a copy, got \(outcome)")
            return
        }
        let stored = try #require(storedFiles().first)
        #expect(storedFiles().count == 1)
        #expect(stored.pathExtension == "webp")
        #expect(try Fixture.isWebP(stored))
        #expect(originalBytes == (try ImageFile.byteCount(of: fixture)))
        #expect(optimizedBytes == (try ImageFile.byteCount(of: stored)))
        #expect(optimizedBytes <= WebPEncoder.defaultBudgetBytes)
        #expect(publishedFileURL()?.lastPathComponent == stored.lastPathComponent)
        #expect(pasteboard.pasteboardItems?.first?.data(forType: NSPasteboard.PasteboardType("org.webmproject.webp")) == (try Data(contentsOf: stored)))
        #expect(outcome.hudLine?.wholeMatch(of: /Copied · \d+ KB → \d+ KB \(−\d+%\)/) != nil)
    }

    @Test func anImpossibleBudgetStillCopiesTheSmallestResult() throws {
        defer { pasteboard.releaseGlobally() }

        let outcome = snip(capturing: .captured, budgetBytes: 10).run()

        guard case let .copied(_, optimizedBytes) = outcome else {
            Issue.record("expected a copy, got \(outcome)")
            return
        }
        #expect(optimizedBytes > 10)
        #expect(storedFiles().map(\.pathExtension) == ["webp"])
    }

    @Test func olderCapturesArePrunedAfterASuccessfulCopy() throws {
        defer { pasteboard.releaseGlobally() }
        let limitedToOne = snip(capturing: .captured, keptCaptures: 1)

        _ = limitedToOne.run()
        let first = try #require(storedFiles().first)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -60)], ofItemAtPath: first.path)
        _ = limitedToOne.run()

        #expect(storedFiles().count == 1)
        #expect(storedFiles().first?.lastPathComponent == publishedFileURL()?.lastPathComponent)
        #expect(storedFiles().first?.lastPathComponent != first.lastPathComponent)
    }

    @Test func escapeChangesNothing() {
        defer { pasteboard.releaseGlobally() }
        let changeCount = pasteboard.changeCount

        #expect(snip(capturing: .cancelled).run() == .cancelled)
        #expect(pasteboard.changeCount == changeCount)
        #expect(storedFiles().isEmpty)
    }

    @Test func aFailedCaptureWithoutPermissionPromptsOnce() {
        defer { pasteboard.releaseGlobally() }
        let changeCount = pasteboard.changeCount

        #expect(snip(capturing: .failed, screenRecordingGranted: false).run() == .screenRecordingDenied)
        #expect(permissionPrompts.count == 1)
        #expect(pasteboard.changeCount == changeCount)
    }

    @Test func aFailedCaptureWithPermissionDoesNotPrompt() {
        defer { pasteboard.releaseGlobally() }

        #expect(snip(capturing: .failed, screenRecordingGranted: true).run() == .captureFailed)
        #expect(permissionPrompts.count == 0)
    }

    @Test func aMissingEncoderCopiesTheOriginal() throws {
        defer { pasteboard.releaseGlobally() }

        #expect(snip(capturing: .captured, encoder: nil).run() == .copiedOriginal)

        let stored = try #require(storedFiles().first)
        #expect(stored.pathExtension == "png")
        #expect(try Data(contentsOf: stored) == (try Data(contentsOf: fixture)))
        #expect(publishedFileURL()?.lastPathComponent == stored.lastPathComponent)
        #expect(pasteboard.pasteboardItems?.first?.data(forType: .png) == (try Data(contentsOf: fixture)))
    }

    @Test func aFailedColorConversionCopiesTheOriginalInsteadOfEncodingIt() throws {
        defer { pasteboard.releaseGlobally() }
        let brokenNormalizer = ColorNormalizer(profile: directory.appendingPathComponent("missing.icc"))

        #expect(snip(capturing: .captured, normalizer: brokenNormalizer).run() == .copiedOriginal)

        #expect(storedFiles().map(\.pathExtension) == ["png"])
        #expect(pasteboard.pasteboardItems?.first?.data(forType: .png) == (try Data(contentsOf: fixture)))
    }

    @Test func anUnusableStoreFailsTheCopyAndKeepsThePreviousClipboard() throws {
        defer { pasteboard.releaseGlobally() }
        let blocker = directory.appendingPathComponent("blocker")
        try Data().write(to: blocker)
        let changeCount = pasteboard.changeCount

        let outcome = snip(capturing: .captured, storeDirectory: blocker.appendingPathComponent("store")).run()

        #expect(outcome == .clipboardFailed)
        #expect(pasteboard.changeCount == changeCount)
        #expect(pasteboard.string(forType: .string) == "previous")
    }

    @Test func aFailedOptimizationWithAnUnusableStoreKeepsThePreviousClipboard() throws {
        defer { pasteboard.releaseGlobally() }
        let blocker = directory.appendingPathComponent("blocker")
        try Data().write(to: blocker)
        let changeCount = pasteboard.changeCount

        let outcome = snip(capturing: .captured, encoder: nil, storeDirectory: blocker.appendingPathComponent("store")).run()

        #expect(outcome == .clipboardFailed)
        #expect(pasteboard.changeCount == changeCount)
        #expect(pasteboard.string(forType: .string) == "previous")
    }

    @Test func aRunInProgressTurnsTheNextOneAwayBeforeCapturing() {
        defer { pasteboard.releaseGlobally() }
        let runInProgress = RunLock.acquire(at: lockFile)
        let changeCount = pasteboard.changeCount

        let outcome = withExtendedLifetime(runInProgress) { snip(capturing: .captured).run() }

        #expect(outcome == .busy)
        #expect(captureCalls.count == 0)
        #expect(pasteboard.changeCount == changeCount)
    }

    @Test func anUnopenableLockFileIsACaptureFailure() {
        defer { pasteboard.releaseGlobally() }
        var blocked = snip(capturing: .captured)
        blocked.lockFile = directory.appendingPathComponent("missing/osnip.lock")

        #expect(blocked.run() == .captureFailed)
        #expect(captureCalls.count == 0)
    }

    @Test func theWorkDirectoryIsGoneAfterTheRun() {
        defer { pasteboard.releaseGlobally() }
        var workDirectory: URL?
        var inspecting = snip(capturing: .cancelled)
        inspecting.capture = { destination in
            workDirectory = destination.deletingLastPathComponent()
            return .cancelled
        }

        _ = inspecting.run()

        #expect(workDirectory.map { FileManager.default.fileExists(atPath: $0.path) } == false)
    }
}
