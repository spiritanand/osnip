import AppKit

public enum ClipboardError: Error {
    case writeRejected
}

public struct Clipboard {
    public enum ImageType: Sendable {
        case webP
        case png

        var pasteboardType: NSPasteboard.PasteboardType {
            switch self {
            case .webP: NSPasteboard.PasteboardType("org.webmproject.webp")
            case .png: .png
            }
        }
    }

    let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func publish(_ file: URL, as imageType: ImageType) throws {
        let imageBytes = try Data(contentsOf: file)
        let item = NSPasteboardItem()
        item.setString(file.absoluteString, forType: .fileURL)
        item.setData(imageBytes, forType: imageType.pasteboardType)
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { throw ClipboardError.writeRejected }
    }
}
