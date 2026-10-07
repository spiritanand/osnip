import Foundation
import Testing
@testable import OsnipCore

struct ScreenCaptureTests {
    let directory: URL
    let destination: URL
    let fixture: URL

    init() throws {
        directory = try Fixture.temporaryDirectory()
        destination = directory.appendingPathComponent("capture.png")
        fixture = directory.appendingPathComponent("fixture.png")
        try Fixture.flatInterface(width: 320, height: 240, at: fixture)
    }

    private func capture(standInBody: String) throws -> CaptureResult {
        let standIn = try Fixture.executableScript(standInBody, named: "screencapture-stand-in", in: directory)
        return ScreenCapture(tool: standIn).captureInteractively(to: destination)
    }

    @Test func passesTheInteractiveArgumentsAndRecognisesACapture() throws {
        let result = try capture(standInBody: """
        [ "$1 $2 $3 $4" = "-i -o -t png" ] || exit 9
        cp "\(fixture.path)" "$5"
        """)
        #expect(result == .captured)
    }

    @Test(arguments: ["exit 0", "exit 1"])
    func aSilentExitWithoutAFileIsACancel(standInBody: String) throws {
        #expect(try capture(standInBody: standInBody) == .cancelled)
    }

    @Test(arguments: [
        "echo 'could not create image from rect' >&2",
        "printf '\\n' >&2",
        ": > \"$5\"",
        "echo not-a-png > \"$5\"",
        "kill -9 $$",
    ])
    func anythingElseIsAFailure(standInBody: String) throws {
        #expect(try capture(standInBody: standInBody) == .failed)
    }

    @Test func aTruncatedImageIsAFailure() throws {
        let truncated = directory.appendingPathComponent("truncated.png")
        try Data(contentsOf: fixture).dropLast(20).write(to: truncated)

        #expect(try capture(standInBody: "cp \"\(truncated.path)\" \"$5\"") == .failed)
    }

    @Test func aToolThatCannotBeStartedIsAFailure() {
        let result = ScreenCapture(tool: directory.appendingPathComponent("missing")).captureInteractively(to: destination)
        #expect(result == .failed)
    }
}
