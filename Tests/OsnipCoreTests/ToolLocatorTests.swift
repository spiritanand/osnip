import Foundation
import Testing
@testable import OsnipCore

struct ToolLocatorTests {
    let first: URL
    let second: URL

    init() throws {
        first = try Fixture.temporaryDirectory()
        second = try Fixture.temporaryDirectory()
    }

    @Test func findsAnExecutableOnTheSearchPath() throws {
        let tool = try Fixture.executableScript("exit 0", named: "osnip-test-tool", in: second)

        let located = ToolLocator.locate("osnip-test-tool", searchPath: "/nonexistent:\(first.path):\(second.path)")

        #expect(located?.path == tool.path)
    }

    @Test func prefersTheEarlierDirectory() throws {
        let earlier = try Fixture.executableScript("exit 0", named: "osnip-test-tool", in: first)
        _ = try Fixture.executableScript("exit 0", named: "osnip-test-tool", in: second)

        #expect(ToolLocator.locate("osnip-test-tool", searchPath: "\(first.path):\(second.path)")?.path == earlier.path)
    }

    @Test func theSearchPathWinsOverTheHomebrewDirectories() throws {
        let standIn = try Fixture.executableScript("exit 0", named: "cwebp", in: first)

        #expect(ToolLocator.locate("cwebp", searchPath: first.path)?.path == standIn.path)
    }

    @Test func skipsADirectoryThatSharesTheToolsName() throws {
        try FileManager.default.createDirectory(at: first.appendingPathComponent("osnip-test-tool"), withIntermediateDirectories: true)
        let tool = try Fixture.executableScript("exit 0", named: "osnip-test-tool", in: second)

        #expect(ToolLocator.locate("osnip-test-tool", searchPath: "\(first.path):\(second.path)")?.path == tool.path)
    }

    @Test func skipsFilesThatAreNotExecutable() throws {
        try Data().write(to: first.appendingPathComponent("osnip-test-tool"))

        #expect(ToolLocator.locate("osnip-test-tool", searchPath: first.path) == nil)
    }

    @Test func fallsBackToTheHomebrewDirectoriesWhenTheSearchPathIsEmpty() {
        #expect(ToolLocator.locate("cwebp", searchPath: "") != nil, "cwebp is required: brew install webp")
    }
}
