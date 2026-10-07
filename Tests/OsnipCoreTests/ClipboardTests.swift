import AppKit
import Testing
@testable import OsnipCore

struct ClipboardTests {
    let directory: URL
    let pasteboard: NSPasteboard

    init() throws {
        directory = try Fixture.temporaryDirectory()
        pasteboard = Fixture.privatePasteboard()
    }

    @Test(arguments: [
        (Clipboard.ImageType.webP, "org.webmproject.webp", "capture.webp"),
        (Clipboard.ImageType.png, "public.png", "capture.png"),
    ])
    func publishesOneItemWithTheFileURLAndTheImageBytes(imageType: Clipboard.ImageType, uniformType: String, name: String) throws {
        defer { pasteboard.releaseGlobally() }
        let file = directory.appendingPathComponent(name)
        let bytes = Data("image bytes".utf8)
        try bytes.write(to: file)

        #expect(Clipboard(pasteboard: pasteboard).publish(file, as: imageType))

        let item = try #require(pasteboard.pasteboardItems?.first)
        #expect(pasteboard.pasteboardItems?.count == 1)
        #expect(item.string(forType: .fileURL) == file.absoluteString)
        #expect(item.data(forType: NSPasteboard.PasteboardType(uniformType)) == bytes)
        #expect(item.types.map(\.rawValue).prefix(2) == ["public.file-url", uniformType])
    }

    @Test func aPathWithSpacesIsPublishedAsAResolvableFileURL() throws {
        defer { pasteboard.releaseGlobally() }
        let spaced = directory.appendingPathComponent("Application Support/os nip", isDirectory: true)
        try FileManager.default.createDirectory(at: spaced, withIntermediateDirectories: true)
        let file = spaced.appendingPathComponent("capture 1.webp")
        try Data("image bytes".utf8).write(to: file)

        #expect(Clipboard(pasteboard: pasteboard).publish(file, as: .webP))

        let published = try #require(pasteboard.pasteboardItems?.first?.string(forType: .fileURL))
        #expect(URL(string: published)?.path == file.path)
    }

    @Test func leavesThePasteboardAloneWhenTheFileCannotBeRead() throws {
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("previous", forType: .string)
        let changeCount = pasteboard.changeCount

        #expect(!Clipboard(pasteboard: pasteboard).publish(directory.appendingPathComponent("missing.webp"), as: .webP))
        #expect(pasteboard.changeCount == changeCount)
        #expect(pasteboard.string(forType: .string) == "previous")
    }
}
