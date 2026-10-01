import AppKit

enum ClipboardError: Error {
    case writeRejected
}

struct Clipboard {
    enum ImageType {
        case webP
        case png

        var fileExtension: String {
            switch self {
            case .webP: "webp"
            case .png: "png"
            }
        }

        var pasteboardType: NSPasteboard.PasteboardType {
            switch self {
            case .webP: NSPasteboard.PasteboardType("org.webmproject.webp")
            case .png: .png
            }
        }
    }

    let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func publish(_ file: URL, as imageType: ImageType) throws {
        let imageBytes = try Data(contentsOf: file)
        let item = NSPasteboardItem()
        item.setString(file.absoluteString, forType: .fileURL)
        item.setData(imageBytes, forType: imageType.pasteboardType)
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { throw ClipboardError.writeRejected }
    }
}
