import AppKit
import SceneKit

/// Builds the island rock and the grass tuft shapes procedurally.
enum IslandBuilder {
    static let radius: Float = 1.6
    /// Grass stays inside this radius so tufts never hang over the edge.
    static let grassRadius: Float = radius * 0.68
    /// Squashes the island into a slight oval.
    static let stretch = SIMD3<Float>(1.15, 1, 0.9)

    static let dirtColor = NSColor(srgbRed: 0.52, green: 0.43, blue: 0.40, alpha: 1)
    static let meadowColor = NSColor(srgbRed: 0.52, green: 0.68, blue: 0.36, alpha: 1)
    static let grassColors = [
        NSColor(srgbRed: 0.47, green: 0.66, blue: 0.30, alpha: 1),
        NSColor(srgbRed: 0.57, green: 0.74, blue: 0.33, alpha: 1),
        NSColor(srgbRed: 0.41, green: 0.58, blue: 0.27, alpha: 1),
    ]

    struct Island {
        let node: SCNNode
        /// Tinted from dirt to meadow as the grass spreads.
        let topMaterial: SCNMaterial
    }

    /// Height of the gently domed top surface at distance `r` from the center.
    static func surfaceHeight(atRadius r: Float) -> Float {
        let t = min(1, r / radius)
        return 0.12 * (1 - t * t)
    }

    /// Surface height at an island-space (x, z) point, taking the oval stretch into account.
    static func surfaceHeight(atX x: Float, z: Float) -> Float {
        surfaceHeight(atRadius: simd_length(SIMD2(x / stretch.x, z / stretch.z)))
    }

    /// Flat lambert material. With a texture, the color tints it, and pixels stay sharp.
    static func flatMaterial(_ color: NSColor, texture: CGImage? = nil) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .lambert
        if let texture {
            material.diffuse.contents = texture
            material.diffuse.magnificationFilter = .nearest
            material.diffuse.minificationFilter = .nearest
            material.diffuse.mipFilter = .none
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            material.multiply.contents = color
        } else {
            material.diffuse.contents = color
        }
        return material
    }

    static func makeIsland(seed: UInt64) -> Island {
        var rng = SeededRandom(seed: seed)
        let sides = 12
        let angles = (0..<sides).map { Float($0) / Float(sides) * 2 * Float.pi + rng.float(-0.1...0.1) }
        // The rock drifts to one side as it goes down, so it isn't a neat cone.
        let leanAngle = rng.float(0...(2 * Float.pi))
        let leanDirection = SIMD3<Float>(cos(leanAngle), 0, sin(leanAngle))

        // Every ring shares the base angles. A ring twisted slightly ahead of the one
        // above it keeps the strips between them from folding over.
        func ring(radius scale: ClosedRange<Float>, twist: Float, height: (Float) -> Float,
                  jitterY: Float, lean: Float = 0) -> [SIMD3<Float>] {
            angles.map { angle in
                let r = IslandBuilder.radius * rng.float(scale)
                let y = height(r) + rng.float(-jitterY...jitterY)
                return SIMD3(cos(angle + twist) * r, y, sin(angle + twist) * r) * IslandBuilder.stretch
                    + leanDirection * lean
            }
        }

        let dome: (Float) -> Float = { IslandBuilder.surfaceHeight(atRadius: $0) }
        let edge = ring(radius: 0.88...1.06, twist: 0, height: dome, jitterY: 0.04)
        let inner = ring(radius: 0.42...0.58, twist: 0.26, height: dome, jitterY: 0.03)
        let rim = edge.map { p in SIMD3(p.x * 0.95, p.y - rng.float(0.13...0.2), p.z * 0.95) }
        let rock1 = ring(radius: 0.70...0.92, twist: 0.1, height: { _ in -0.3 }, jitterY: 0.06, lean: 0.05)
        let rock2 = ring(radius: 0.48...0.78, twist: 0.2, height: { _ in -0.5 }, jitterY: 0.07, lean: 0.12)
        let rock3 = ring(radius: 0.32...0.56, twist: 0.3, height: { _ in -0.68 }, jitterY: 0.06, lean: 0.18)
        let rock4 = ring(radius: 0.12...0.28, twist: 0.4, height: { _ in -0.84 }, jitterY: 0.05, lean: 0.24)
        let tip = leanDirection * 0.28 + SIMD3<Float>(rng.float(-0.06...0.06), -1.0, rng.float(-0.06...0.06))
        let center = SIMD3<Float>(0, dome(0) + 0.02, 0)

        // Top: grayscale per-face shades, colored by the shared top material.
        var top = LowPolyMesh()
        let up = SIMD3<Float>(0, 1, 0)
        func topShade() -> SIMD4<Float> { vertexColor(1, 1, 1, shade: rng.float(0.9...1.0)) }
        for i in 0..<sides {
            let j = (i + 1) % sides
            top.addTriangle(center, inner[i], inner[j], outward: up, color: topShade())
            top.addTriangle(edge[i], inner[i], edge[j], outward: up, color: topShade())
            top.addTriangle(inner[i], inner[j], edge[j], outward: up, color: topShade())
        }

        // Sides: dirt band, then rock tapering down to a point.
        var body = LowPolyMesh()
        func band(_ upper: [SIMD3<Float>], _ lower: [SIMD3<Float>], r: Float, g: Float, b: Float) {
            for i in 0..<sides {
                let j = (i + 1) % sides
                body.addSideTriangle(upper[i], lower[i], upper[j], color: vertexColor(r, g, b, shade: rng.float(0.8...1.06)))
                body.addSideTriangle(lower[i], lower[j], upper[j], color: vertexColor(r, g, b, shade: rng.float(0.8...1.06)))
            }
        }
        band(edge, rim, r: 0.44, g: 0.38, b: 0.43)
        band(rim, rock1, r: 0.44, g: 0.44, b: 0.52)
        band(rock1, rock2, r: 0.46, g: 0.50, b: 0.60)
        band(rock2, rock3, r: 0.40, g: 0.44, b: 0.55)
        band(rock3, rock4, r: 0.36, g: 0.39, b: 0.50)
        for i in 0..<sides {
            body.addSideTriangle(rock4[i], rock4[(i + 1) % sides], tip,
                                 color: vertexColor(0.32, 0.35, 0.46, shade: rng.float(0.8...1.05)))
        }

        let topMaterial = flatMaterial(dirtColor, texture: Textures.soil)
        let node = SCNNode()
        node.addChildNode(SCNNode(geometry: top.makeGeometry(material: topMaterial)))
        node.addChildNode(SCNNode(geometry: body.makeGeometry(material: flatMaterial(.white, texture: Textures.rock))))
        return Island(node: node, topMaterial: topMaterial)
    }

    /// A few tuft variants, each a cluster of thin three-sided blades.
    static func makeTuftGeometries(seed: UInt64, count: Int) -> [SCNGeometry] {
        var rng = SeededRandom(seed: seed)
        let materials = grassColors.map { IslandBuilder.flatMaterial($0) }
        return (0..<count).map { variant in
            var mesh = LowPolyMesh()
            for _ in 0..<Int.random(in: 3...5, using: &rng) {
                let base = SIMD3<Float>(rng.float(-0.03...0.03), 0, rng.float(-0.03...0.03))
                let lean = SIMD3<Float>(rng.float(-0.03...0.03), 0, rng.float(-0.03...0.03))
                let tip = base + lean + SIMD3(0, rng.float(0.07...0.15), 0)
                let width = rng.float(0.011...0.018)
                let turn = rng.float(0...(2 * Float.pi))
                let corners = (0..<3).map { k -> SIMD3<Float> in
                    let a = turn + Float(k) * 2 * Float.pi / 3
                    return base + SIMD3(cos(a) * width, 0, sin(a) * width)
                }
                for k in 0..<3 {
                    let c0 = corners[k], c1 = corners[(k + 1) % 3]
                    mesh.addTriangle(c0, c1, tip, outward: (c0 + c1) / 2 - base,
                                     color: vertexColor(1, 1, 1, shade: rng.float(0.82...1.0)))
                }
            }
            return mesh.makeGeometry(material: materials[variant % materials.count])
        }
    }
}
