import Foundation
import Testing
@testable import OsnipCore

struct RaycastScriptTests {
    let script = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("raycast/osnip.sh")

    @Test func isAValidExecutableSilentScriptCommand() throws {
        let source = try String(contentsOf: script, encoding: .utf8)

        #expect(try Shell.run(URL(fileURLWithPath: "/bin/bash"), ["-n", script.path]).succeeded)
        #expect(FileManager.default.isExecutableFile(atPath: script.path))
        #expect(source.contains("# @raycast.schemaVersion 1\n"))
        #expect(source.contains("# @raycast.mode silent\n"))
    }
}
