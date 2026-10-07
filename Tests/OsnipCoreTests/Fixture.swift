import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import OsnipCore

struct RGB {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
}

enum Fixture {
    static func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("osnip-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func privatePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("osnip.tests.\(UUID().uuidString)"))
    }

    static func cwebp() throws -> URL {
        try #require(ToolLocator.locate("cwebp"), "cwebp is required: brew install webp")
    }

    static func writePNG(
        width: Int,
        height: Int,
        colorSpaceName: CFString = CGColorSpace.sRGB,
        to url: URL,
        alpha: (Int, Int) -> UInt8 = { _, _ in 255 },
        pixel: (Int, Int) -> RGB
    ) throws {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let color = pixel(x, y)
                let offset = (y * width + x) * 4
                bytes[offset] = color.red
                bytes[offset + 1] = color.green
                bytes[offset + 2] = color.blue
                bytes[offset + 3] = alpha(x, y)
            }
        }
        let colorSpace = try #require(CGColorSpace(name: colorSpaceName))
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        let image = try #require(CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
    }

    static func flatInterface(width: Int, height: Int, at url: URL) throws {
        let background = RGB(red: 28, green: 28, blue: 30)
        let text = RGB(red: 229, green: 229, blue: 234)
        try writePNG(width: width, height: height, to: url) { x, y in
            let row = y / 40
            let insideBar = y % 40 >= 12 && y % 40 < 26 && x >= 24 && x < 24 + (width - 48) * (row % 5 + 3) / 8
            return insideBar ? text : background
        }
    }

    static func noise(width: Int, height: Int, at url: URL) throws {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        func nextByte() -> UInt8 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return UInt8(truncatingIfNeeded: state >> 24)
        }
        try writePNG(width: width, height: height, to: url) { _, _ in
            RGB(red: nextByte(), green: nextByte(), blue: nextByte())
        }
    }

    static func solid(_ color: RGB, colorSpaceName: CFString, width: Int, height: Int, at url: URL) throws {
        try writePNG(width: width, height: height, colorSpaceName: colorSpaceName, to: url) { _, _ in color }
    }

    static func storedPixel(of url: URL, x: Int, y: Int) throws -> (color: RGB, alpha: UInt8) {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let colorSpace = try #require(image.colorSpace)
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(
            data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let offset = (y * image.width + x) * 4
        return (RGB(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2]), bytes[offset + 3])
    }

    static func sRGBEquivalent(ofDisplayP3 color: RGB) throws -> RGB {
        let displayP3 = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let components = [color.red, color.green, color.blue].map { CGFloat($0) / 255 } + [1]
        let source = try #require(CGColor(colorSpace: displayP3, components: components))
        let converted = try #require(source.converted(to: sRGB, intent: .relativeColorimetric, options: nil)?.components)
        let bytes = converted.prefix(3).map { UInt8(min(max(($0 * 255).rounded(), 0), 255)) }
        return RGB(red: bytes[0], green: bytes[1], blue: bytes[2])
    }

    static func channelsAreClose(_ first: RGB, _ second: RGB) -> Bool {
        [(first.red, second.red), (first.green, second.green), (first.blue, second.blue)]
            .allSatisfy { abs(Int($0.0) - Int($0.1)) <= 3 }
    }

    static func embeddedProfileName(of url: URL) throws -> String? {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        return properties?[kCGImagePropertyProfileName] as? String
    }

    static func transparentCorners(width: Int, height: Int, at url: URL) throws {
        let isCorner: (Int, Int) -> Bool = { x, y in (x < 8 || x >= width - 8) && (y < 8 || y >= height - 8) }
        try writePNG(width: width, height: height, to: url, alpha: { x, y in isCorner(x, y) ? 0 : 255 }) { _, _ in
            RGB(red: 40, green: 90, blue: 200)
        }
    }

    static func executableScript(_ body: String, named name: String, in directory: URL) throws -> URL {
        let script = directory.appendingPathComponent(name)
        try Data("#!/bin/sh\n\(body)\n".utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return script
    }

    static func isWebP(_ url: URL) throws -> Bool {
        let header = try Data(contentsOf: url).prefix(12)
        return header.prefix(4) == Data("RIFF".utf8) && header.suffix(4) == Data("WEBP".utf8)
    }
}
