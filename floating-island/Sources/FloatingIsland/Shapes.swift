import AppKit
import SceneKit

/// Simple flat-shaded building blocks. `at` is the center of the shape's base.
enum Shapes {
    static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    static func box(_ width: CGFloat, _ height: CGFloat, _ length: CGFloat,
                    _ color: NSColor, texture: CGImage? = nil, at base: SCNVector3) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: length, chamferRadius: 0)
        geometry.materials = [IslandBuilder.flatMaterial(color, texture: texture)]
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(base.x, base.y + height / 2, base.z)
        return node
    }

    static func pyramid(_ width: CGFloat, _ height: CGFloat, _ length: CGFloat,
                        _ color: NSColor, texture: CGImage? = nil, at base: SCNVector3) -> SCNNode {
        let geometry = SCNPyramid(width: width, height: height, length: length)
        geometry.materials = [IslandBuilder.flatMaterial(color, texture: texture)]
        let node = SCNNode(geometry: geometry)
        node.position = base
        return node
    }

    static func sphere(radius: CGFloat, _ color: NSColor, texture: CGImage? = nil,
                       at center: SCNVector3, scale: SCNVector3 = SCNVector3(1, 1, 1)) -> SCNNode {
        let geometry = SCNSphere(radius: radius)
        geometry.segmentCount = 12
        geometry.materials = [IslandBuilder.flatMaterial(color, texture: texture)]
        let node = SCNNode(geometry: geometry)
        node.position = center
        node.scale = scale
        return node
    }

    static func capsule(radius: CGFloat, height: CGFloat, _ color: NSColor, texture: CGImage? = nil,
                        at center: SCNVector3) -> SCNNode {
        let geometry = SCNCapsule(capRadius: radius, height: height)
        geometry.radialSegmentCount = 8
        geometry.capSegmentCount = 3
        geometry.materials = [IslandBuilder.flatMaterial(color, texture: texture)]
        let node = SCNNode(geometry: geometry)
        node.position = center
        return node
    }

    /// Low-poly ellipsoid with flat-shaded facets. `at` is its center.
    static func blob(radius: CGFloat, _ color: NSColor, texture: CGImage? = nil, rings: Int = 4, sides: Int = 7,
                     at center: SCNVector3, scale: SCNVector3 = SCNVector3(1, 1, 1)) -> SCNNode {
        let r = Float(radius)
        func point(_ ring: Int, _ k: Int) -> SIMD3<Float> {
            let phi = Float.pi * Float(ring) / Float(rings)
            let theta = 2 * Float.pi * Float(k) / Float(sides)
            return SIMD3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) * r
        }
        var mesh = LowPolyMesh()
        mesh.uvScale = 1 / (2 * r)
        for ring in 0..<rings {
            for k in 0..<sides {
                let a = point(ring, k), b = point(ring, k + 1), c = point(ring + 1, k), d = point(ring + 1, k + 1)
                // Skip the triangles that collapse to a line at the poles.
                if ring > 0 { mesh.addTriangle(a, b, d, outward: (a + b + d) / 3) }
                if ring < rings - 1 { mesh.addTriangle(a, d, c, outward: (a + d + c) / 3) }
            }
        }
        let node = SCNNode(geometry: mesh.makeGeometry(material: IslandBuilder.flatMaterial(color, texture: texture)))
        node.position = center
        node.scale = scale
        return node
    }

    /// A six-sided post.
    static func post(radius: CGFloat, height: CGFloat, _ color: NSColor, at base: SCNVector3) -> SCNNode {
        let geometry = SCNCylinder(radius: radius, height: height)
        geometry.radialSegmentCount = 6
        geometry.materials = [IslandBuilder.flatMaterial(color)]
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(base.x, base.y + height / 2, base.z)
        return node
    }
}
