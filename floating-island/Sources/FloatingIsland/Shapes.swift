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
