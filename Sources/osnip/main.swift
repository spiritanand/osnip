import Foundation
import OsnipCore

switch Invocation(arguments: Array(CommandLine.arguments.dropFirst())) {
case .snip:
    let outcome = Snip.live().run()
    if let line = outcome.hudLine { print(line) }
    exit(outcome.exitCode)
case .printVersion:
    print(Osnip.version)
case .printUsage:
    print(Invocation.usage)
case .rejectArguments:
    FileHandle.standardError.write(Data((Invocation.usage + "\n").utf8))
    exit(64)
}
