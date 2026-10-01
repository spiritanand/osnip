import CoreGraphics
import Foundation
import Testing
@testable import OsnipCore

struct ColorNormalizerTests {
    let directory: URL
    let displayP3Color = RGB(red: 204, green: 102, blue: 77)

    init() throws {
        directory = try Fixture.temporaryDirectory()
    }

    private func expectedSRGB() throws -> RGB {
        let displayP3 = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let components = [displayP3Color.red, displayP3Color.green, displayP3Color.blue].map { CGFloat($0) / 255 } + [1]
        let color = try #require(CGColor(colorSpace: displayP3, components: components))
        let converted = try #require(color.converted(to: sRGB, intent: .relativeColorimetric, options: nil)?.components)
        let bytes = converted.prefix(3).map { UInt8(($0 * 255).rounded().clamped(to: 0...255)) }
        return RGB(red: bytes[0], green: bytes[1], blue: bytes[2])
    }

    @Test func convertsDisplayP3PixelsIntoSRGBAndLeavesTheSourceUntouched() throws {
        let source = directory.appendingPathComponent("capture.png")
        let destination = directory.appendingPathComponent("srgb.png")
        try Fixture.solid(displayP3Color, colorSpaceName: CGColorSpace.displayP3, width: 64, height: 48, at: source)
        let sourceBytes = try Data(contentsOf: source)

        try ColorNormalizer().makeSRGBCopy(of: source, at: destination)

        #expect(try Fixture.embeddedProfileName(of: source) == "Display P3")
        #expect(try Fixture.embeddedProfileName(of: destination) == "sRGB IEC61966-2.1")
        let stored = try Fixture.storedPixel(of: destination)
        let expected = try expectedSRGB()
        #expect(abs(Int(stored.red) - Int(expected.red)) <= 3)
        #expect(abs(Int(stored.green) - Int(expected.green)) <= 3)
        #expect(abs(Int(stored.blue) - Int(expected.blue)) <= 3)
        #expect(abs(Int(stored.red) - Int(displayP3Color.red)) > 3)
        #expect(ImageFile.pixelSize(of: destination)?.width == 64)
        #expect(ImageFile.pixelSize(of: destination)?.height == 48)
        #expect(try Data(contentsOf: source) == sourceBytes)
    }

    @Test func keepsTransparency() throws {
        let source = directory.appendingPathComponent("window.png")
        let destination = directory.appendingPathComponent("srgb.png")
        try Fixture.transparentCorners(width: 64, height: 48, at: source)

        try ColorNormalizer().makeSRGBCopy(of: source, at: destination)

        #expect(try Fixture.storedAlpha(of: destination, x: 0, y: 0) == 0)
        #expect(try Fixture.storedAlpha(of: destination, x: 32, y: 24) == 255)
    }

    @Test func failsWhenTheProfileIsMissing() throws {
        let source = directory.appendingPathComponent("capture.png")
        try Fixture.flatInterface(width: 64, height: 48, at: source)
        let normalizer = ColorNormalizer(profile: directory.appendingPathComponent("missing.icc"))

        #expect(throws: OptimizationError.colorNormalizationFailed) {
            try normalizer.makeSRGBCopy(of: source, at: directory.appendingPathComponent("srgb.png"))
        }
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
