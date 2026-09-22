import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Why a rendered image could not be compared with its reference.
enum ReferenceImageError: Error, CustomStringConvertible {
    case noPixels
    case unreadable(URL)
    case unwritable(URL)

    var description: String {
        switch self {
        case .noPixels:
            "could not draw the image into an RGBA buffer"

        case let .unreadable(url):
            "could not read a PNG at \(url.path)"

        case let .unwritable(url):
            "could not write a PNG to \(url.path)"
        }
    }
}

/// Reading and writing reference images as PNG files.
enum PNGFile {
    static func read(_ url: URL) throws(ReferenceImageError) -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw .unreadable(url)
        }
        return image
    }

    static func write(_ image: CGImage, to url: URL) throws(ReferenceImageError) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
        } catch {
            throw .unwritable(url)
        }
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil,
        ) else {
            throw .unwritable(url)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw .unwritable(url)
        }
    }
}
