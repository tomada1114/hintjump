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

    private let actual: RGBAPixels
    private let reference: RGBAPixels
    private let tolerance: Int

    /// The reference faded to a quarter, with every differing pixel painted solid red.
    ///
    /// Drawn on demand rather than during the comparison: only a failed comparison
    /// writes it, and building it for every passing one made a large scene — the
    /// Settings window's, over a million pixels — take seconds to compare in an
    /// unoptimized test build.
    var highlighted: RGBAPixels {
        let stride = RGBAPixels.bytesPerPixel
        var marked = reference
        for start in Swift.stride(from: 0, to: reference.bytes.count, by: stride) {
            let delta = actual.bytes.withUnsafeBufferPointer { actualBytes in
                reference.bytes.withUnsafeBufferPointer { referenceBytes in
                    Self.delta(actualBytes, referenceBytes, at: start)
                }
            }
            if delta > tolerance {
                marked.bytes.replaceSubrange(start ..< start + stride, with: Self.red)
            } else {
                for channel in start ..< start + Self.colorChannels {
                    let distanceToWhite = RGBAPixels.channelMax - reference.bytes[channel]
                    marked.bytes[channel] = RGBAPixels.channelMax - distanceToWhite / Self.fade
                }
                marked.bytes[start + Self.colorChannels] = RGBAPixels.channelMax
            }
        }
        return marked
    }

    /// Compares `actual` with `reference`, which must be the same size, counting a pixel
    /// as different when any channel moved by more than `tolerance`.
    init(actual: RGBAPixels, reference: RGBAPixels, tolerance: Int) {
        self.actual = actual
        self.reference = reference
        self.tolerance = tolerance
        guard !Self.identical(actual.bytes, reference.bytes) else {
            differingPixels = 0
            largestChannelDelta = 0
            return
        }
        var differing = 0
        var largest = 0
        actual.bytes.withUnsafeBufferPointer { actualBytes in
            reference.bytes.withUnsafeBufferPointer { referenceBytes in
                let stride = RGBAPixels.bytesPerPixel
                for start in Swift.stride(from: 0, to: referenceBytes.count, by: stride) {
                    let delta = Self.delta(actualBytes, referenceBytes, at: start)
                    largest = max(largest, delta)
                    if delta > tolerance {
                        differing += 1
                    }
                }
            }
        }
        differingPixels = differing
        largestChannelDelta = largest
    }

    /// Whether the two byte arrays are the same, compared as memory: the common case, a
    /// render that matches its reference exactly, then costs no per-pixel loop.
    private static func identical(_ actual: [UInt8], _ reference: [UInt8]) -> Bool {
        guard actual.count == reference.count else {
            return false
        }
        return actual.withUnsafeBytes { actualBytes in
            reference.withUnsafeBytes { referenceBytes in
                guard let actualBase = actualBytes.baseAddress,
                      let referenceBase = referenceBytes.baseAddress
                else {
                    return actualBytes.isEmpty
                }
                return memcmp(actualBase, referenceBase, actualBytes.count) == 0
            }
        }
    }

    /// The largest change in any channel of the pixel that starts at byte `start`.
    ///
    /// Over buffer pointers rather than arrays: an unoptimized test build checks bounds
    /// and copies on every array subscript, which over a million pixels is seconds.
    private static func delta(
        _ actual: UnsafeBufferPointer<UInt8>,
        _ reference: UnsafeBufferPointer<UInt8>,
        at start: Int,
    ) -> Int {
        var largest = 0
        for index in start ..< start + RGBAPixels.bytesPerPixel {
            let change = abs(Int(actual[index]) - Int(reference[index]))
            if change > largest {
                largest = change
            }
        }
        return largest
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
