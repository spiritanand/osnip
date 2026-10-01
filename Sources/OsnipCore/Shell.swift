import Foundation

struct ShellResult {
    let exitedNormally: Bool
    let status: Int32
    let standardError: String

    var succeeded: Bool { exitedNormally && status == 0 }
}

enum Shell {
    static func run(_ executable: URL, _ arguments: [String]) throws -> ShellResult {
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

    static func start(_ executable: URL, _ arguments: [String]) throws -> Process {
        let process = makeProcess(executable, arguments, standardError: FileHandle.nullDevice)
        try process.run()
        return process
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
