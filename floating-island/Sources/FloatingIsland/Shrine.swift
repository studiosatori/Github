import AppKit
import SceneKit
import simd

/// The little wooden temple and torii gate on top of the island, and the ground they take up.
enum Shrine {
    /// Island-space (x, z) positions. The camera looks from +z, so the temple sits toward the back.
    static let templePosition = SIMD2<Float>(-0.2, -0.4)
    static let toriiPosition = SIMD2<Float>(0.5, 0.45)
    static let toriiHalfSpan: Float = 0.12

    private struct Footprint {
        let minX, maxX, minZ, maxZ: Float

        init(center: SIMD2<Float>, left: Float, right: Float, back: Float, front: Float) {
            minX = center.x - left
            maxX = center.x + right
            minZ = center.y - back
            maxZ = center.y + front
        }

        func contains(_ p: SIMD2<Float>, margin: Float) -> Bool {
            p.x > minX - margin && p.x < maxX + margin && p.y > minZ - margin && p.y < maxZ + margin
        }
    }

    private static let footprints = [
        Footprint(center: templePosition, left: 0.39, right: 0.39, back: 0.31, front: 0.41),
        Footprint(center: toriiPosition - SIMD2(toriiHalfSpan, 0), left: 0.02, right: 0.02, back: 0.02, front: 0.02),
        Footprint(center: toriiPosition + SIMD2(toriiHalfSpan, 0), left: 0.02, right: 0.02, back: 0.02, front: 0.02),
    ]

    /// Whether something at `p` would bump into the temple or the gate posts.
    static func isBlocked(_ p: SIMD2<Float>, margin: Float) -> Bool {
        footprints.contains { $0.contains(p, margin: margin) }
    }

    static func makeNode() -> SCNNode {
        let node = SCNNode()
        let temple = makeTemple()
        temple.position = groundPosition(templePosition)
        node.addChildNode(temple)
        let torii = makeTorii()
        torii.position = groundPosition(toriiPosition)
        node.addChildNode(torii)
        return node
    }

    private static func groundPosition(_ p: SIMD2<Float>) -> SCNVector3 {
        scnVector(SIMD3(p.x, IslandBuilder.surfaceHeight(atX: p.x, z: p.y), p.y))
    }

    private static let stone = Shapes.color(0.55, 0.57, 0.64)
    private static let wood = Shapes.color(0.62, 0.42, 0.27)
    private static let darkWood = Shapes.color(0.34, 0.22, 0.17)
    private static let vermilion = Shapes.color(0.78, 0.30, 0.22)
    private static let roofTiles = Shapes.color(0.24, 0.27, 0.36)
    private static let paper = Shapes.color(0.93, 0.90, 0.82)

    /// Stone base, wooden hall with a paper door, red pillars, and a two-tier roof. Faces +z.
    private static func makeTemple() -> SCNNode {
        let t = SCNNode()
        // The base sinks into the ground so the domed top never shows a gap underneath.
        t.addChildNode(Shapes.box(0.78, 0.13, 0.62, stone, texture: Textures.rock, at: SCNVector3(0, -0.05, 0)))
        t.addChildNode(Shapes.box(0.26, 0.07, 0.10, stone, texture: Textures.rock, at: SCNVector3(0, -0.03, 0.36)))
        t.addChildNode(Shapes.box(0.68, 0.03, 0.52, darkWood, texture: Textures.planks, at: SCNVector3(0, 0.08, 0)))

        let floor: CGFloat = 0.11
        t.addChildNode(Shapes.box(0.48, 0.26, 0.34, wood, texture: Textures.planks, at: SCNVector3(0, floor, -0.02)))
        t.addChildNode(Shapes.box(0.20, 0.18, 0.01, paper, at: SCNVector3(0, floor + 0.02, 0.155)))
        t.addChildNode(Shapes.box(0.012, 0.18, 0.012, darkWood, texture: Textures.planks, at: SCNVector3(0, floor + 0.02, 0.162)))
        for x: CGFloat in [-0.3, 0.3] {
            for z: CGFloat in [-0.22, 0.22] {
                t.addChildNode(Shapes.post(radius: 0.022, height: 0.3, vermilion, at: SCNVector3(x, floor, z)))
            }
        }
        t.addChildNode(Shapes.box(0.66, 0.04, 0.50, vermilion, at: SCNVector3(0, 0.39, 0)))

        // Lower roof with wide eaves.
        t.addChildNode(Shapes.box(0.92, 0.025, 0.74, roofTiles, texture: Textures.tiles, at: SCNVector3(0, 0.43, 0)))
        t.addChildNode(Shapes.pyramid(0.92, 0.2, 0.74, roofTiles, texture: Textures.tiles, at: SCNVector3(0, 0.455, 0)))
        // Upper tier.
        t.addChildNode(Shapes.box(0.30, 0.14, 0.24, wood, texture: Textures.planks, at: SCNVector3(0, 0.58, 0)))
        t.addChildNode(Shapes.box(0.50, 0.02, 0.40, roofTiles, texture: Textures.tiles, at: SCNVector3(0, 0.72, 0)))
        t.addChildNode(Shapes.pyramid(0.50, 0.16, 0.40, roofTiles, texture: Textures.tiles, at: SCNVector3(0, 0.74, 0)))
        t.addChildNode(Shapes.post(radius: 0.012, height: 0.08, darkWood, at: SCNVector3(0, 0.86, 0)))
        return t
    }

    /// Two red posts and two cross beams. Tall enough for the cat to walk through.
    private static func makeTorii() -> SCNNode {
        let t = SCNNode()
        let span = CGFloat(toriiHalfSpan)
        for x in [-span, span] {
            t.addChildNode(Shapes.post(radius: 0.018, height: 0.43, vermilion, at: SCNVector3(x, -0.03, 0)))
        }
        t.addChildNode(Shapes.box(0.30, 0.02, 0.025, vermilion, at: SCNVector3(0, 0.32, 0)))
        t.addChildNode(Shapes.box(0.36, 0.025, 0.035, vermilion, at: SCNVector3(0, 0.37, 0)))
        t.addChildNode(Shapes.box(0.42, 0.03, 0.045, Shapes.color(0.18, 0.18, 0.22), at: SCNVector3(0, 0.395, 0)))
        return t
    }
}
