import AppKit
import SceneKit

/// Builds the island rock and the grass tuft shapes procedurally.
enum IslandBuilder {
    static let radius: Float = 1.6
    /// Grass grows out to here; leaves near the rim spill a little over the edge.
    static let grassRadius: Float = radius * 0.8
    /// Squashes the island into a slight oval.
    static let stretch = SIMD3<Float>(1.15, 1, 0.9)

    static let dirtColor = NSColor(srgbRed: 0.40, green: 0.30, blue: 0.22, alpha: 1)
    static let meadowColor = NSColor(srgbRed: 0.28, green: 0.42, blue: 0.17, alpha: 1)
    /// Leaf colors, dark at the base and light at the tip (sRGB).
    static let leafPalettes: [(base: SIMD3<Float>, tip: SIMD3<Float>)] = [
        (SIMD3(0.16, 0.30, 0.10), SIMD3(0.45, 0.66, 0.24)),
        (SIMD3(0.18, 0.34, 0.11), SIMD3(0.55, 0.72, 0.28)),
        (SIMD3(0.14, 0.27, 0.10), SIMD3(0.38, 0.58, 0.22)),
    ]

    struct Island {
        let node: SCNNode
        /// Tinted from dirt to meadow as the grass spreads.
        let topMaterial: SCNMaterial
        /// The top rim and the ring just below it, for hanging vines over the edge.
        let edge: [SIMD3<Float>]
        let rim: [SIMD3<Float>]
    }

    /// Double-sided material colored only by vertex colors, for leaves.
    static func foliageMaterial() -> SCNMaterial {
        let material = flatMaterial(.white)
        material.isDoubleSided = true
        return material
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
        let rim = edge.map { p in SIMD3(p.x * 0.95, p.y - rng.float(0.2...0.3), p.z * 0.95) }
        let rock1 = ring(radius: 0.70...0.92, twist: 0.1, height: { _ in -0.58 }, jitterY: 0.1, lean: 0.06)
        let rock2 = ring(radius: 0.48...0.78, twist: 0.2, height: { _ in -0.98 }, jitterY: 0.12, lean: 0.14)
        let rock3 = ring(radius: 0.32...0.56, twist: 0.3, height: { _ in -1.34 }, jitterY: 0.1, lean: 0.22)
        let rock4 = ring(radius: 0.12...0.28, twist: 0.4, height: { _ in -1.66 }, jitterY: 0.08, lean: 0.3)
        let tip = leanDirection * 0.34 + SIMD3<Float>(rng.float(-0.06...0.06), -1.98, rng.float(-0.06...0.06))
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
                body.addSideTriangle(upper[i], lower[i], upper[j], color: vertexColor(r, g, b, shade: rng.float(0.9...1.05)))
                body.addSideTriangle(lower[i], lower[j], upper[j], color: vertexColor(r, g, b, shade: rng.float(0.9...1.05)))
            }
        }
        // Warm, earthy browns, darker toward the bottom.
        band(edge, rim, r: 0.33, g: 0.24, b: 0.18)
        band(rim, rock1, r: 0.38, g: 0.28, b: 0.22)
        band(rock1, rock2, r: 0.40, g: 0.30, b: 0.25)
        band(rock2, rock3, r: 0.35, g: 0.26, b: 0.23)
        band(rock3, rock4, r: 0.30, g: 0.23, b: 0.21)
        for i in 0..<sides {
            body.addSideTriangle(rock4[i], rock4[(i + 1) % sides], tip,
                                 color: vertexColor(0.26, 0.20, 0.19, shade: rng.float(0.9...1.05)))
        }

        let topMaterial = flatMaterial(dirtColor, texture: Textures.soil)
        let node = SCNNode()
        node.addChildNode(SCNNode(geometry: top.makeGeometry(material: topMaterial)))
        node.addChildNode(SCNNode(geometry: body.makeGeometry(material: flatMaterial(.white, texture: Textures.rock))))
        return Island(node: node, topMaterial: topMaterial, edge: edge, rim: rim)
    }

    /// Leafy tuft variants: broad leaves that rise and bend outward, dark at the base and light
    /// at the tip. Every fourth variant has a little yellow flower poking out.
    static func makeTuftGeometries(seed: UInt64, count: Int) -> [SCNGeometry] {
        var rng = SeededRandom(seed: seed)
        let material = foliageMaterial()
        let up = SIMD3<Float>(0, 1, 0)
        return (0..<count).map { variant in
            var mesh = LowPolyMesh()
            let palette = leafPalettes[variant % leafPalettes.count]
            for _ in 0..<Int.random(in: 5...8, using: &rng) {
                let yaw = rng.float(0...(2 * Float.pi))
                let out = SIMD3<Float>(cos(yaw), 0, sin(yaw))
                let side = SIMD3<Float>(-out.z, 0, out.x)
                let length = rng.float(0.1...0.18)
                let width = rng.float(0.018...0.03)
                let lean = rng.float(0.25...0.7)
                let base = out * rng.float(0...0.02)
                let mid = base + SIMD3(0, length * 0.55, 0) + out * (length * lean * 0.3)
                let tip = base + SIMD3(0, length, 0) + out * (length * lean)
                let shade = rng.float(0.88...1.08)
                let dark = vertexColor(palette.base, shade: shade)
                let light = vertexColor(palette.tip, shade: shade)
                let middle = (dark + light) / 2
                let b0 = base - side * width * 0.3, b1 = base + side * width * 0.3
                let m0 = mid - side * width, m1 = mid + side * width
                mesh.addTriangle(b0, b1, m1, normal: up, colors: (dark, dark, middle))
                mesh.addTriangle(b0, m1, m0, normal: up, colors: (dark, middle, middle))
                mesh.addTriangle(m0, m1, tip, normal: up, colors: (middle, middle, light))
            }
            if variant % 4 == 3 {
                addFlower(to: &mesh, height: rng.float(0.17...0.24), rng: &rng)
            }
            return mesh.makeGeometry(material: material)
        }
    }

    /// A thin stem with a five-petal yellow flower on top, facing up.
    private static func addFlower(to mesh: inout LowPolyMesh, height: Float, rng: inout SeededRandom) {
        let up = SIMD3<Float>(0, 1, 0)
        let stem = vertexColor(SIMD3(0.24, 0.42, 0.16))
        let top = SIMD3<Float>(rng.float(-0.02...0.02), height, rng.float(-0.02...0.02))
        let w = SIMD3<Float>(0.004, 0, 0)
        mesh.addTriangle(-w, w, top, normal: up, colors: (stem, stem, stem))
        mesh.addTriangle(SIMD3(0, 0, -0.004), SIMD3(0, 0, 0.004), top, normal: up, colors: (stem, stem, stem))

        let petal = vertexColor(SIMD3(0.98, 0.80, 0.22))
        let petalTip = vertexColor(SIMD3(1.0, 0.88, 0.40))
        let heart = vertexColor(SIMD3(0.62, 0.36, 0.12))
        let turn = rng.float(0...(2 * Float.pi))
        for k in 0..<5 {
            let a = turn + Float(k) * 2 * Float.pi / 5
            let left = top + SIMD3(cos(a - 0.35), 0, sin(a - 0.35)) * 0.03
            let right = top + SIMD3(cos(a + 0.35), 0, sin(a + 0.35)) * 0.03
            mesh.addTriangle(top, left, right, normal: up, colors: (petal, petalTip, petalTip))
        }
        let lifted = top + SIMD3(0, 0.003, 0)
        for k in 0..<5 {
            let a = Float(k) * 2 * Float.pi / 5, b = Float(k + 1) * 2 * Float.pi / 5
            mesh.addTriangle(lifted, lifted + SIMD3(cos(a), 0, sin(a)) * 0.01, lifted + SIMD3(cos(b), 0, sin(b)) * 0.01,
                             normal: up, colors: (heart, heart, heart))
        }
    }
}
