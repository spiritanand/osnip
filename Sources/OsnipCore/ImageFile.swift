import Foundation
import ImageIO

enum ImageFile {
    static let pngTrailer = Data([0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82])

    static func byteCount(of url: URL) -> Int? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }

    static func pixelSize(of url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0
        else { return nil }
        return (width, height)
    }

    // ImageIO decodes a truncated PNG without reporting it, so completeness is read from the trailing IEND chunk.
    static func isCompletePNG(_ url: URL) -> Bool {
        guard pixelSize(of: url) != nil,
              let bytes = try? Data(contentsOf: url, options: .mappedIfSafe)
        else { return false }
        return bytes.suffix(pngTrailer.count) == pngTrailer
    }
}
