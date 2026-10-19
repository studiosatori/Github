import CoreGraphics
import Foundation

/// Tiny 32×32 procedural textures. Shown with nearest-neighbor filtering for a crunchy PS1 look.
/// They're grayscale and get tinted by vertex colors or the material color.
enum Textures {
    private static let size = 32

    /// Blotchy stone with a few dark cracks.
    static let rock: CGImage = {
        var rng = SeededRandom(seed: 11)
        let blotches = (0..<64).map { _ in rng.float(0.84...1.0) }
        var pixels = (0..<size * size).map { i in
            blotches[(i / size / 4) * 8 + (i % size) / 4] * rng.float(0.92...1.0)
        }
        for _ in 0..<6 {
            var x = Int(rng.next() % UInt64(size)), y = Int(rng.next() % UInt64(size))
            for _ in 0..<9 {
                pixels[y * size + x] *= 0.62
                x = (x + Int(rng.next() % 3) + size - 1) % size
                y = (y + 1) % size
            }
        }
        return image(pixels)
    }()

    /// Grainy ground with light and dark specks.
    static let soil: CGImage = {
        var rng = SeededRandom(seed: 12)
        let clumps = (0..<256).map { _ in rng.float(0.9...1.0) }
        let pixels = (0..<size * size).map { i -> Float in
            let base = clumps[(i / size / 2) * 16 + (i % size) / 2] * rng.float(0.93...1.0)
            switch rng.next() % 14 {
            case 0: return base * 0.72
            case 1: return 1
            default: return base
            }
        }
        return image(pixels)
    }()

    /// Vertical planks with dark seams and a bit of grain.
    static let planks: CGImage = {
        var rng = SeededRandom(seed: 13)
        let tones = (0..<4).map { _ in rng.float(0.8...1.0) }
        let grain = (0..<size).map { _ in rng.float(0.88...1.0) }
        let pixels = (0..<size * size).map { i -> Float in
            let x = i % size
            if x % 8 == 0 { return 0.55 }
            return tones[x / 8] * grain[x] * rng.float(0.95...1.0)
        }
        return image(pixels)
    }()

    /// Rows of roof tiles, staggered like brickwork.
    static let tiles: CGImage = {
        var rng = SeededRandom(seed: 14)
        let tones = (0..<64).map { _ in rng.float(0.85...1.0) }
        let pixels = (0..<size * size).map { i -> Float in
            let x = i % size, y = i / size
            if y % 4 == 0 { return 0.55 }
            let shifted = x + (y / 4 % 2) * 2
            if shifted % 4 == 0 { return 0.72 }
            return tones[(y / 4) * 8 + (shifted / 4) % 8]
        }
        return image(pixels)
    }()

    private static func image(_ gray: [Float]) -> CGImage {
        let bytes = gray.flatMap { value -> [UInt8] in
            let b = UInt8(max(0, min(1, value)) * 255)
            return [b, b, b, 255]
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
}
