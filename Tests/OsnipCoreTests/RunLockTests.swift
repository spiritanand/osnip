import Foundation
import Testing
@testable import OsnipCore

struct RunLockTests {
    let lockFile: URL

    init() throws {
        lockFile = try Fixture.temporaryDirectory().appendingPathComponent("osnip.lock")
    }

    private func isAcquired(_ acquisition: RunLock.Acquisition) -> Bool {
        if case .acquired = acquisition { return true }
        return false
    }

    private func isHeldByAnotherRun(_ acquisition: RunLock.Acquisition) -> Bool {
        if case .heldByAnotherRun = acquisition { return true }
        return false
    }

    @Test func aSecondRunIsTurnedAwayUntilTheFirstLetsGo() {
        var first: RunLock.Acquisition? = RunLock.acquire(at: lockFile)
        #expect(first.map(isAcquired) == true)
        #expect(isHeldByAnotherRun(RunLock.acquire(at: lockFile)))

        first = nil

        #expect(isAcquired(RunLock.acquire(at: lockFile)))
    }

    private func descriptorCopyOutlivingItsLock() throws -> Int32 {
        guard case let .acquired(lock) = RunLock.acquire(at: lockFile) else {
            throw CocoaError(.fileLocking)
        }
        let copy = dup(lock.descriptor)
        try #require(copy >= 0)
        return copy
    }

    @Test func lettingGoReleasesTheLockEvenWhileACopyOfItsDescriptorIsStillOpen() throws {
        let copyAChildProcessWouldInherit = try descriptorCopyOutlivingItsLock()
        defer { close(copyAChildProcessWouldInherit) }

        #expect(isAcquired(RunLock.acquire(at: lockFile)))
    }

    @Test func aLeftoverLockFileFromAnEarlierRunDoesNotBlock() throws {
        try Data().write(to: lockFile)

        #expect(isAcquired(RunLock.acquire(at: lockFile)))
    }

    @Test func aLockFileThatCannotBeOpenedIsUnavailable() {
        let unopenable = lockFile.deletingLastPathComponent().appendingPathComponent("missing/osnip.lock")
        if case .unavailable = RunLock.acquire(at: unopenable) { return }
        Issue.record("expected the lock to be unavailable")
    }
}
