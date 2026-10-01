import Foundation
import Testing
@testable import OsnipCore

struct ImageFileTests {
    let directory: URL
    let png: URL

    init() throws {
        directory = try Fixture.temporaryDirectory()
        png = directory.appendingPathComponent("image.png")
        try Fixture.flatInterface(width: 320, height: 240, at: png)
    }

    @Test func reportsTheByteCountAndPixelSizeOfAnImage() throws {
        #expect(ImageFile.byteCount(of: png) == (try Data(contentsOf: png)).count)
        #expect(ImageFile.pixelSize(of: png)?.width == 320)
        #expect(ImageFile.pixelSize(of: png)?.height == 240)
        #expect(ImageFile.isCompletePNG(png))
    }

    @Test(arguments: [20, 200])
    func aTruncatedPNGIsNotComplete(missingBytes: Int) throws {
        let truncated = directory.appendingPathComponent("truncated.png")
        try Data(contentsOf: png).dropLast(missingBytes).write(to: truncated)

        #expect(!ImageFile.isCompletePNG(truncated))
    }

    @Test func aFileThatIsNotAnImageHasNoPixelSize() throws {
        let garbage = directory.appendingPathComponent("garbage.png")
        try Data("not a png".utf8).write(to: garbage)

        #expect(ImageFile.pixelSize(of: garbage) == nil)
        #expect(!ImageFile.isCompletePNG(garbage))
    }

    @Test func aMissingFileHasNoByteCount() {
        let missing = directory.appendingPathComponent("missing.png")

        #expect(ImageFile.byteCount(of: missing) == nil)
        #expect(!ImageFile.isCompletePNG(missing))
    }
}
