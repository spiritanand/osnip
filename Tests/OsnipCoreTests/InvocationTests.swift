import Testing
@testable import OsnipCore

@Test(arguments: [
    ([String](), Invocation.snip),
    (["--version"], Invocation.printVersion),
    (["--help"], Invocation.printUsage),
    (["--quality", "80"], Invocation.rejectArguments),
    (["--version", "extra"], Invocation.rejectArguments),
    (["screenshot.png"], Invocation.rejectArguments),
])
func readsArguments(arguments: [String], expected: Invocation) {
    #expect(Invocation(arguments: arguments) == expected)
}
