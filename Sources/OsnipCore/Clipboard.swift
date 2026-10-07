import AppKit

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

    var pasteboard = NSPasteboard.general

    func publish(_ file: URL, as imageType: ImageType) -> Bool {
        guard let imageBytes = try? Data(contentsOf: file) else { return false }
        let item = NSPasteboardItem()
        item.setString(file.absoluteString, forType: .fileURL)
        item.setData(imageBytes, forType: imageType.pasteboardType)
        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }
}
