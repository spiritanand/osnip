import Foundation

public final class RunLock {
    public enum Acquisition {
        case acquired(RunLock)
        case heldByAnotherRun
        case unavailable
    }

    public static var defaultFile: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("osnip.lock")
    }

    private let descriptor: Int32

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    deinit {
        close(descriptor)
    }

    public static func acquire(at file: URL) -> Acquisition {
        // O_CLOEXEC keeps child processes from inheriting the descriptor and with it the lock.
        let descriptor = open(file.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { return .unavailable }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let heldByAnotherRun = errno == EWOULDBLOCK
            close(descriptor)
            return heldByAnotherRun ? .heldByAnotherRun : .unavailable
        }
        return .acquired(RunLock(descriptor: descriptor))
    }
}
