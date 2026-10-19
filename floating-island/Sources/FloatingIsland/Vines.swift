import SceneKit
import simd

/// Leafy vines that hang over the island's edge. They grow in, one by one, as the meadow fills.
final class Vines {
    let node = SCNNode()
    private var strands: [(node: SCNNode, start: Double)] = []

    init(edge: [SIMD3<Float>], rim: [SIMD3<Float>], seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        let material = IslandBuilder.foliageMaterial()
        for i in edge.indices {
            let j = (i + 1) % edge.count
            for _ in 0..<2 where rng.float(0...1) < 0.75 {
                let t = rng.float(0.15...0.85)
                let anchor = edge[i] + (edge[j] - edge[i]) * t
                let below = rim[i] + (rim[j] - rim[i]) * t
                // Hang along the slope of the side, so the vine hugs the wall.
                let down = simd_normalize(below - anchor)
                let out = simd_normalize(SIMD3(anchor.x, 0, anchor.z))
                let strand = SCNNode(geometry: Self.makeStrand(length: rng.float(0.25...0.6), down: down, out: out,
                                                               rng: &rng, material: material))
                strand.position = scnVector(anchor + out * 0.015)
                node.addChildNode(strand)
                strands.append((strand, Double(rng.float(0.15...0.9))))
            }
        }
    }

    /// Each strand appears once the meadow passes its own threshold, and grows down over a while.
    func update(coverage: Double) {
        for strand in strands {
            let growth = CGFloat(min(1, max(0, (coverage - strand.start) / 0.12)))
            strand.node.isHidden = growth <= 0
            strand.node.scale = SCNVector3(1, max(growth, 0.01), 1)
        }
    }

    /// A stem with pairs of leaves along it, getting smaller toward the end. Hangs from the origin.
    private static func makeStrand(length: Float, down: SIMD3<Float>, out: SIMD3<Float>,
                                   rng: inout SeededRandom, material: SCNMaterial) -> SCNGeometry {
        var mesh = LowPolyMesh()
        let side = simd_normalize(simd_cross(down, out))
        let palette = IslandBuilder.leafPalettes[Int(rng.next() % UInt64(IslandBuilder.leafPalettes.count))]
        let stem = vertexColor(palette.base)
        let tip = down * length
        mesh.addTriangle(-side * 0.004, side * 0.004, tip, normal: out, colors: (stem, stem, stem))

        let pairs = Int(length / 0.035)
        for k in 0..<pairs {
            let t = (Float(k) + 0.5) / Float(pairs)
            let point = down * (length * t)
            let size = 0.05 * (1 - t * 0.6) * rng.float(0.85...1.1)
            let shade = rng.float(0.88...1.08)
            let dark = vertexColor(palette.base, shade: shade)
            let light = vertexColor(palette.tip, shade: shade)
            for s: Float in [-1, 1] {
                // A diamond-shaped leaf angled down and away from the stem.
                let leafTip = point + side * (s * size) + down * (size * 0.5) + out * 0.01
                let middle = point + side * (s * size * 0.45) + down * (size * 0.25)
                let width = down * (size * 0.22)
                mesh.addTriangle(point, middle - width, leafTip, normal: out, colors: (dark, dark, light))
                mesh.addTriangle(point, leafTip, middle + width, normal: out, colors: (dark, light, dark))
            }
        }
        return mesh.makeGeometry(material: material)
    }
}
