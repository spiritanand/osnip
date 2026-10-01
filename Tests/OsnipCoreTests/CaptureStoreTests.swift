import Foundation
import Testing
@testable import OsnipCore

struct CaptureStoreTests {
    let workDirectory: URL
    let storeDirectory: URL

    init() throws {
        workDirectory = try Fixture.temporaryDirectory()
        storeDirectory = workDirectory.appendingPathComponent("store", isDirectory: true)
    }

    private func incomingFile(_ contents: String) throws -> URL {
        let file = workDirectory.appendingPathComponent(UUID().uuidString)
        try Data(contents.utf8).write(to: file)
        return file
    }

    private func setModificationDate(_ date: Date, of file: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
    }

    private func addCaptures(agedSeconds ages: [Int], to store: CaptureStore) throws -> [URL] {
        try ages.map { age in
            let namedLaterTheOlderItIs = Date(timeIntervalSince1970: Double(1_000_000 + age))
            let file = try store.add(try incomingFile("age \(age)"), fileExtension: "webp", capturedAt: namedLaterTheOlderItIs)
            try setModificationDate(Date(timeIntervalSinceNow: Double(-age)), of: file)
            return file
        }
    }

    private func storedNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: storeDirectory.path).sorted()
    }

    @Test func movesTheFileIntoTheStoreUnderATimestampedName() throws {
        let incoming = try incomingFile("webp bytes")
        let capturedAt = Date(timeIntervalSince1970: 1_790_000_000.5)
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = .current
        let local = localCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: capturedAt)
        let fields = try [local.year, local.month, local.day, local.hour, local.minute, local.second].map { try #require($0) }

        let stored = try CaptureStore(directory: storeDirectory).add(incoming, fileExtension: "webp", capturedAt: capturedAt)

        #expect(stored.deletingLastPathComponent().lastPathComponent == "store")
        #expect(stored.lastPathComponent == String(
            format: "osnip-%04d%02d%02d-%02d%02d%02d-500.webp", fields[0], fields[1], fields[2], fields[3], fields[4], fields[5]
        ))
        #expect(try String(contentsOf: stored, encoding: .utf8) == "webp bytes")
        #expect(!FileManager.default.fileExists(atPath: incoming.path))
    }

    @Test func givesCollidingNamesANumericSuffixAndOverwritesNothing() throws {
        let store = CaptureStore(directory: storeDirectory)
        let sameInstant = Date(timeIntervalSince1970: 1_790_000_000)
        let first = try store.add(try incomingFile("first"), fileExtension: "webp", capturedAt: sameInstant)
        let second = try store.add(try incomingFile("second"), fileExtension: "webp", capturedAt: sameInstant)
        let third = try store.add(try incomingFile("third"), fileExtension: "webp", capturedAt: sameInstant)

        let stem = first.deletingPathExtension().lastPathComponent
        #expect(second.lastPathComponent == "\(stem)-2.webp")
        #expect(third.lastPathComponent == "\(stem)-3.webp")
        #expect(try String(contentsOf: first, encoding: .utf8) == "first")
        #expect(try String(contentsOf: second, encoding: .utf8) == "second")
    }

    @Test func pruningKeepsTheAddedFileAndTheNewestOthers() throws {
        let store = CaptureStore(directory: storeDirectory, keptCaptures: 3)
        let stored = try addCaptures(agedSeconds: [500, 400, 300, 200, 100], to: store)

        store.prune(keeping: stored[4])

        #expect(try storedNames() == [stored[2], stored[3], stored[4]].map(\.lastPathComponent).sorted())
    }

    @Test func pruningStillHoldsExactlyTheLimitWhenTheAddedFileLooksOldest() throws {
        let store = CaptureStore(directory: storeDirectory, keptCaptures: 3)
        let stored = try addCaptures(agedSeconds: [400, 300, 200, 100], to: store)
        let added = try store.add(try incomingFile("clock went backwards"), fileExtension: "webp", capturedAt: Date(timeIntervalSince1970: 1))
        try setModificationDate(Date(timeIntervalSinceNow: -9_000), of: added)

        store.prune(keeping: added)

        #expect(try storedNames() == [added, stored[2], stored[3]].map(\.lastPathComponent).sorted())
    }

    @Test func pruningLeavesForeignFilesAlone() throws {
        let store = CaptureStore(directory: storeDirectory, keptCaptures: 1)
        let older = try store.add(try incomingFile("older"), fileExtension: "webp", capturedAt: Date(timeIntervalSince1970: 1))
        try setModificationDate(Date(timeIntervalSinceNow: -100), of: older)
        let foreign = storeDirectory.appendingPathComponent("notes.txt")
        try Data("mine".utf8).write(to: foreign)
        try setModificationDate(Date(timeIntervalSinceNow: -99_000), of: foreign)
        let prefixedDirectory = storeDirectory.appendingPathComponent("osnip-backup", isDirectory: true)
        try FileManager.default.createDirectory(at: prefixedDirectory, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: prefixedDirectory.appendingPathComponent("sentinel.txt"))
        try setModificationDate(Date(timeIntervalSinceNow: -99_000), of: prefixedDirectory)
        let added = try store.add(try incomingFile("newer"), fileExtension: "png", capturedAt: Date(timeIntervalSince1970: 2))

        store.prune(keeping: added)

        #expect(try storedNames() == [added.lastPathComponent, "notes.txt", "osnip-backup"].sorted())
        #expect(FileManager.default.fileExists(atPath: prefixedDirectory.appendingPathComponent("sentinel.txt").path))
    }

    @Test func failsWhenTheDirectoryCannotBeCreated() throws {
        let blocker = workDirectory.appendingPathComponent("blocker")
        try Data().write(to: blocker)
        let store = CaptureStore(directory: blocker.appendingPathComponent("store", isDirectory: true))
        let incoming = try incomingFile("bytes")

        #expect(throws: (any Error).self) { try store.add(incoming, fileExtension: "webp") }
        #expect(FileManager.default.fileExists(atPath: incoming.path))
    }
}
