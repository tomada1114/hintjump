import CoreGraphics
import Foundation

/// How two images of the same size differ.
struct PixelDifference {
    /// How far the highlighted image fades the unchanged pixels toward white: to a quarter.
    private static let fade: UInt8 = 4
    private static let red: [UInt8] = [RGBAPixels.channelMax, 0, 0, RGBAPixels.channelMax]
    private static let colorChannels = 3

    /// How many pixels differ by more than the tolerance in any channel.
    let differingPixels: Int
    /// The largest difference seen in any channel of any pixel, 0–255.
    let largestChannelDelta: Int
    /// The reference faded to a quarter, with every differing pixel painted solid red.
    let highlighted: RGBAPixels

    /// Compares `actual` with `reference`, which must be the same size, counting a pixel
    /// as different when any channel moved by more than `tolerance`.
    init(actual: RGBAPixels, reference: RGBAPixels, tolerance: Int) {
        let stride = RGBAPixels.bytesPerPixel
        var differing = 0
        var largest = 0
        var marked = reference
        for start in Swift.stride(from: 0, to: reference.bytes.count, by: stride) {
            let delta = (start ..< start + stride)
                .map { abs(Int(actual.bytes[$0]) - Int(reference.bytes[$0])) }
                .max() ?? 0
            largest = max(largest, delta)
            if delta > tolerance {
                differing += 1
                marked.bytes.replaceSubrange(start ..< start + stride, with: Self.red)
            } else {
                for channel in start ..< start + Self.colorChannels {
                    let distanceToWhite = RGBAPixels.channelMax - reference.bytes[channel]
                    marked.bytes[channel] = RGBAPixels.channelMax - distanceToWhite / Self.fade
                }
                marked.bytes[start + Self.colorChannels] = RGBAPixels.channelMax
            }
        }
        differingPixels = differing
        largestChannelDelta = largest
        highlighted = marked
    }
}

/// An image's pixels as 8-bit sRGB RGBA, premultiplied, row by row — the one layout both
/// the rendered image and the decoded reference are drawn into, so two images compare
/// byte for byte whatever format each arrived in.
struct RGBAPixels: Equatable {
    static let bytesPerPixel = 4
    static let bitsPerComponent = 8
    static let channelMax: UInt8 = .max

    private static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    private static var colorSpace: CGColorSpace? {
        CGColorSpace(name: CGColorSpace.sRGB)
    }

    let width: Int
    let height: Int
    var bytes: [UInt8]

    init(width: Int, height: Int, bytes: [UInt8]) {
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    init(_ image: CGImage) throws(ReferenceImageError) {
        width = image.width
        height = image.height
        bytes = [UInt8](repeating: 0, count: image.width * image.height * Self.bytesPerPixel)
        let drawn = bytes.withUnsafeMutableBytes { buffer in
            guard let space = Self.colorSpace,
                  let context = CGContext(
                      data: buffer.baseAddress,
                      width: image.width,
                      height: image.height,
                      bitsPerComponent: Self.bitsPerComponent,
                      bytesPerRow: image.width * Self.bytesPerPixel,
                      space: space,
                      bitmapInfo: Self.bitmapInfo,
                  )
            else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else {
            throw .noPixels
        }
    }

    /// These pixels as an image, for writing to a file.
    func image() -> CGImage? {
        guard let space = Self.colorSpace,
              let provider = CGDataProvider(data: Data(bytes) as CFData)
        else {
            return nil
        }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: Self.bitsPerComponent,
            bitsPerPixel: Self.bitsPerComponent * Self.bytesPerPixel,
            bytesPerRow: width * Self.bytesPerPixel,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: Self.bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent,
        )
    }
}
