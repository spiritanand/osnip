import Foundation

enum ByteCount {
    static func formatted(_ bytes: Int) -> String {
        let kilobytes = max(1, Int((Double(bytes) / 1000).rounded()))
        guard kilobytes >= 1000 else { return "\(kilobytes) KB" }
        return String(format: "%.1f MB", Double(bytes) / 1_000_000)
    }
}
