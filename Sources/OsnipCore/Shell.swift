import Foundation

public struct ShellResult: Sendable {
    public let exitedNormally: Bool
    public let status: Int32
    public let standardError: String

    public var succeeded: Bool { exitedNormally && status == 0 }
}

public enum Shell {
    public static func run(_ executable: URL, _ arguments: [String]) throws -> ShellResult {
        let errorPipe = Pipe()
        let process = makeProcess(executable, arguments, standardError: errorPipe)
        try process.run()
        let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ShellResult(
            exitedNormally: process.terminationReason == .exit,
            status: process.terminationStatus,
            standardError: String(decoding: errorOutput, as: UTF8.self)
        )
    }

    private static func makeProcess(_ executable: URL, _ arguments: [String], standardError: Any) -> Process {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = standardError
        return process
    }
}
