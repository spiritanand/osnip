import Foundation

public struct ColorNormalizer: Sendable {
    public static let systemSRGBProfile = URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/sRGB Profile.icc")
    static let sips = URL(fileURLWithPath: "/usr/bin/sips")

    public let profile: URL

    public init(profile: URL = ColorNormalizer.systemSRGBProfile) {
        self.profile = profile
    }

    public func makeSRGBCopy(of source: URL, at destination: URL) throws {
        let result = try Shell.run(Self.sips, ["--matchTo", profile.path, source.path, "--out", destination.path])
        guard result.succeeded, ImageFile.isCompletePNG(destination) else {
            throw OptimizationError.colorNormalizationFailed
        }
    }
}
