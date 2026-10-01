import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import OsnipCore

struct RGB: Equatable {
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
