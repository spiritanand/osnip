import Foundation

struct ColorNormalizer {
    static let systemSRGBProfile = URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/sRGB Profile.icc")
    static let sips = URL(fileURLWithPath: "/usr/bin/sips")

    let profile: URL

    init(profile: URL = ColorNormalizer.systemSRGBProfile) {
        self.profile = profile
    }

    func makeSRGBCopy(of source: URL, at destination: URL) -> Bool {
        let arguments = ["--matchTo", profile.path, source.path, "--out", destination.path]
        guard let result = try? Shell.run(Self.sips, arguments) else { return false }
        return result.succeeded && ImageFile.isCompletePNG(destination)
    }
}
