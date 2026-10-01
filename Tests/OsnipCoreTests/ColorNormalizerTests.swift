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

    @Test func convertsDisplayP3PixelsIntoSRGBAndLeavesTheSourceUntouched() throws {
        let source = directory.appendingPathComponent("capture.png")
        let destination = directory.appendingPathComponent("srgb.png")
        try Fixture.solid(displayP3Color, colorSpaceName: CGColorSpace.displayP3, width: 64, height: 48, at: source)
        let sourceBytes = try Data(contentsOf: source)

        #expect(ColorNormalizer().makeSRGBCopy(of: source, at: destination))

        #expect(try Fixture.embeddedProfileName(of: source) == "Display P3")
        #expect(try Fixture.embeddedProfileName(of: destination) == "sRGB IEC61966-2.1")
        let stored = try Fixture.storedPixel(of: destination, x: 32, y: 24).color
        #expect(Fixture.channelsAreClose(stored, try Fixture.sRGBEquivalent(ofDisplayP3: displayP3Color)))
        #expect(!Fixture.channelsAreClose(stored, displayP3Color))
        #expect(ImageFile.pixelSize(of: destination)?.width == 64)
        #expect(ImageFile.pixelSize(of: destination)?.height == 48)
        #expect(try Data(contentsOf: source) == sourceBytes)
    }

    @Test func keepsTransparency() throws {
        let source = directory.appendingPathComponent("window.png")
        let destination = directory.appendingPathComponent("srgb.png")
        try Fixture.transparentCorners(width: 64, height: 48, at: source)

        #expect(ColorNormalizer().makeSRGBCopy(of: source, at: destination))

        #expect(try Fixture.storedPixel(of: destination, x: 0, y: 0).alpha == 0)
        #expect(try Fixture.storedPixel(of: destination, x: 32, y: 24).alpha == 255)
    }

    @Test func reportsFailureWhenTheProfileIsMissing() throws {
        let source = directory.appendingPathComponent("capture.png")
        try Fixture.flatInterface(width: 64, height: 48, at: source)
        let normalizer = ColorNormalizer(profile: directory.appendingPathComponent("missing.icc"))

        #expect(!normalizer.makeSRGBCopy(of: source, at: directory.appendingPathComponent("srgb.png")))
    }
}
