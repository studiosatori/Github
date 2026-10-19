import CoreGraphics
import Foundation
import simd

/// Tiny 32×32 procedural textures. Shown with nearest-neighbor filtering for a soft lo-fi look.
/// They're grayscale and get tinted by vertex colors or the material color.
enum Textures {
    private static let size = 32

    /// Soft, blotchy earth and stone.
    static let rock: CGImage = {
        var rng = SeededRandom(seed: 11)
        let blotches = (0..<64).map { _ in rng.float(0.84...1.0) }
        let pixels = (0..<size * size).map { i in
            blotches[(i / size / 4) * 8 + (i % size) / 4] * rng.float(0.95...1.0)
        }
        return image(pixels)
    }()

    /// Cream fur with wavy orange tabby stripes, in rows so they wrap around spheres and capsules.
    /// In color, unlike the others; use it with a white material.
    static let tabby: CGImage = {
        var rng = SeededRandom(seed: 15)
        let cream = SIMD3<Float>(0.99, 0.90, 0.74)
        let orange = SIMD3<Float>(0.90, 0.58, 0.30)
        let wave = (0..<size).map { x in Int((sin(Float(x) / Float(size) * 4 * Float.pi) * 1.5).rounded()) + 2 }
        let pixels = (0..<size * size).map { i -> SIMD3<Float> in
            let x = i % size, y = i / size
            return ((y + wave[x]) % 8 < 3 ? orange : cream) * rng.float(0.95...1.0)
        }
        return image(rgb: pixels)
    }()

    /// Standing-seam metal roofing: a light rib and a shadow line every 4 pixels.
    static let metal: CGImage = {
        var rng = SeededRandom(seed: 16)
        let pixels = (0..<size * size).map { i -> Float in
            switch (i / size) % 4 {
            case 0: return 1
            case 1: return 0.72
            default: return rng.float(0.88...0.93)
            }
        }
        return image(pixels)
    }()

    /// Orange sail canvas on a dark wooden lattice, with a few worn, darker patches. In color.
    static let lattice: CGImage = {
        var rng = SeededRandom(seed: 17)
        let canvas = SIMD3<Float>(0.80, 0.48, 0.26)
        let wood = SIMD3<Float>(0.36, 0.22, 0.14)
        let wear = (0..<16).map { _ in rng.float(0...1) < 0.25 ? rng.float(0.7...0.85) : 1 }
        let pixels = (0..<size * size).map { i -> SIMD3<Float> in
            let x = i % size, y = i / size
            if x % 8 == 0 || y % 8 == 0 { return wood * rng.float(0.9...1.0) }
            return canvas * wear[(y / 8) * 4 + x / 8] * rng.float(0.93...1.0)
        }
        return image(rgb: pixels)
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
        image(rgb: gray.map { SIMD3(repeating: $0) })
    }

    private static func image(rgb: [SIMD3<Float>]) -> CGImage {
        let bytes = rgb.flatMap { color -> [UInt8] in
            let c = simd_clamp(color, SIMD3(repeating: 0), SIMD3(repeating: 1)) * 255
            return [UInt8(c.x), UInt8(c.y), UInt8(c.z), 255]
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
}
