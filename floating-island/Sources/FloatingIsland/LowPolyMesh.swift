import SceneKit
import simd

/// Collects triangles with one normal per face, which gives the faceted low-poly look.
struct LowPolyMesh {
    private var positions: [SCNVector3] = []
    private var normals: [SCNVector3] = []
    private var colors: [SIMD4<Float>] = []
    private var uvs: [CGPoint] = []
    /// Texture repeats per island unit.
    var uvScale: Float = 1.2

    /// Adds a triangle whose normal faces `outward`; the winding is fixed up to match.
    mutating func addTriangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>,
                              outward: SIMD3<Float>, color: SIMD4<Float> = SIMD4<Float>(repeating: 1)) {
        var (b, c) = (b, c)
        var normal = simd_normalize(simd_cross(b - a, c - a))
        if simd_dot(normal, outward) < 0 {
            swap(&b, &c)
            normal = -normal
        }
        for vertex in [a, b, c] {
            positions.append(scnVector(vertex))
            normals.append(scnVector(normal))
            colors.append(color)
            uvs.append(uv(for: vertex, normal: normal))
        }
    }

    /// Box projection: each face takes the texture from whichever side it mostly faces.
    private func uv(for v: SIMD3<Float>, normal n: SIMD3<Float>) -> CGPoint {
        let p: SIMD2<Float>
        if abs(n.y) >= abs(n.x) && abs(n.y) >= abs(n.z) {
            p = SIMD2(v.x, v.z)
        } else if abs(n.x) >= abs(n.z) {
            p = SIMD2(v.z, -v.y)
        } else {
            p = SIMD2(v.x, -v.y)
        }
        return CGPoint(x: CGFloat(p.x * uvScale), y: CGFloat(p.y * uvScale))
    }

    /// Adds a triangle on the island's side, facing away from the vertical axis.
    mutating func addSideTriangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>,
                                  color: SIMD4<Float>) {
        let centroid = (a + b + c) / 3
        addTriangle(a, b, c, outward: SIMD3(centroid.x, 0, centroid.z), color: color)
    }

    func makeGeometry(material: SCNMaterial) -> SCNGeometry {
        let colorData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
        let colorSource = SCNGeometrySource(
            data: colorData, semantic: .color, vectorCount: colors.count,
            usesFloatComponents: true, componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<SIMD4<Float>>.stride)
        let element = SCNGeometryElement(indices: Array(0..<Int32(positions.count)), primitiveType: .triangles)
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals),
                      SCNGeometrySource(textureCoordinates: uvs), colorSource],
            elements: [element])
        geometry.materials = [material]
        return geometry
    }
}

func scnVector(_ v: SIMD3<Float>) -> SCNVector3 {
    SCNVector3(CGFloat(v.x), CGFloat(v.y), CGFloat(v.z))
}

/// sRGB color converted to linear, which is how SceneKit reads vertex colors.
func vertexColor(_ r: Float, _ g: Float, _ b: Float, shade: Float = 1) -> SIMD4<Float> {
    SIMD4(pow(r * shade, 2.2), pow(g * shade, 2.2), pow(b * shade, 2.2), 1)
}

/// Small deterministic RNG (SplitMix64), so the same seed always builds the same island.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func float(_ range: ClosedRange<Float>) -> Float {
        Float.random(in: range, using: &self)
    }
}
