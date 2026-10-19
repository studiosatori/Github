import AppKit
import SceneKit
import simd

/// The little cabin with its deck, and the ground it takes up.
enum Landmarks {
    /// Island-space (x, z) positions. The camera looks from +z, so the cabin sits toward the back,
    /// turned a little so you see its front and one side.
    static let cabinPosition = SIMD2<Float>(-0.15, -0.45)
    static let cabinAngle: Float = -0.5

    /// A rectangle that may be turned around the vertical axis.
    private struct Footprint {
        let center: SIMD2<Float>
        let halfSize: SIMD2<Float>
        var angle: Float = 0

        func contains(_ p: SIMD2<Float>, margin: Float) -> Bool {
            let d = p - center
            let local = SIMD2(d.x * cos(angle) - d.y * sin(angle), d.x * sin(angle) + d.y * cos(angle))
            return abs(local.x) < halfSize.x + margin && abs(local.y) < halfSize.y + margin
        }
    }

    /// Where a point on a node turned by `angle` (as SceneKit turns it) ends up.
    private static func rotated(_ p: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
        SIMD2(p.x * cos(angle) + p.y * sin(angle), -p.x * sin(angle) + p.y * cos(angle))
    }

    private static let footprints =
        // Cabin, deck and steps, in the cabin's own frame: x -0.67...0.7, z -0.37...0.8.
        [Footprint(center: cabinPosition + rotated(SIMD2(0.015, 0.215), by: cabinAngle),
                   halfSize: SIMD2(0.685, 0.585), angle: cabinAngle)]

    /// Whether something at `p` would bump into the cabin.
    static func isBlocked(_ p: SIMD2<Float>, margin: Float) -> Bool {
        footprints.contains { $0.contains(p, margin: margin) }
    }

    static func makeNode() -> SCNNode {
        let node = SCNNode()
        let cabin = makeCabin()
        cabin.position = groundPosition(cabinPosition)
        cabin.eulerAngles.y = CGFloat(cabinAngle)
        node.addChildNode(cabin)
        return node
    }

    private static func groundPosition(_ p: SIMD2<Float>) -> SCNVector3 {
        scnVector(SIMD3(p.x, IslandBuilder.surfaceHeight(atX: p.x, z: p.y), p.y))
    }

    private static let cedar = Shapes.color(0.84, 0.58, 0.32)
    private static let deckBoards = Shapes.color(0.66, 0.66, 0.66)
    private static let deckRim = Shapes.color(0.76, 0.48, 0.30)
    private static let roofMetal = Shapes.color(0.68, 0.76, 0.82)
    private static let trim = Shapes.color(0.12, 0.12, 0.13)
    private static let glass = Shapes.color(0.42, 0.58, 0.64)
    private static let foundation = Shapes.color(0.28, 0.28, 0.31)

    /// Repeats a node's texture so boards and ribs come out narrow.
    private static func repeatTexture(_ node: SCNNode, _ x: CGFloat, _ y: CGFloat) -> SCNNode {
        node.geometry?.firstMaterial?.diffuse.contentsTransform = SCNMatrix4MakeScale(x, y, 1)
        return node
    }

    /// Modern little cabin: vertical cedar boards, metal gable roof, black-framed windows and a
    /// sliding glass door (tall enough for the cat), with a deck, two lounge chairs and a step. Faces +z.
    private static func makeCabin() -> SCNNode {
        let c = SCNNode()
        // The house is squashed to 60% height so it sits low and cozy next to the deck.
        let house = SCNNode()
        house.scale = SCNVector3(1, 0.6, 1)
        c.addChildNode(house)
        let wallTop: CGFloat = 1.13
        let front: CGFloat = 0.35

        c.addChildNode(Shapes.box(0.86, 0.18, 0.66, foundation, at: SCNVector3(0, -0.1, 0)))
        house.addChildNode(repeatTexture(Shapes.box(0.9, wallTop - 0.08, 0.7, cedar, texture: Textures.planks,
                                                at: SCNVector3(0, 0.08, 0)), 4, 1))
        house.addChildNode(makeGables(halfWidth: 0.45, halfDepth: Float(front), baseY: Float(wallTop), peakY: 1.56))
        house.addChildNode(makeRoof(wallTop: wallTop))
        // Downspout on the front corner.
        house.addChildNode(Shapes.box(0.025, wallTop - 0.08, 0.025, trim, at: SCNVector3(-0.44, 0.08, front + 0.015)))

        // Tall window and sliding door on the front.
        func window(width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) {
            house.addChildNode(Shapes.box(width, height, 0.02, trim, at: SCNVector3(x, y, front + 0.002)))
            house.addChildNode(Shapes.box(width - 0.04, height - 0.04, 0.012, glass, at: SCNVector3(x, y + 0.02, front + 0.012)))
        }
        window(width: 0.22, height: 0.55, x: -0.27, y: 0.45)
        let doorX: CGFloat = 0.16
        house.addChildNode(Shapes.box(0.42, 0.92, 0.02, trim, at: SCNVector3(doorX, 0.15, front + 0.002)))
        for dx: CGFloat in [-0.1, 0.1] {
            house.addChildNode(Shapes.box(0.18, 0.86, 0.012, glass, at: SCNVector3(doorX + dx, 0.18, front + 0.012)))
        }
        house.addChildNode(Shapes.box(0.02, 0.92, 0.016, trim, at: SCNVector3(doorX, 0.15, front + 0.014)))
        // Two small high windows on the right side.
        for z: CGFloat in [-0.15, 0.15] {
            house.addChildNode(Shapes.box(0.02, 0.14, 0.22, trim, at: SCNVector3(0.452, 0.82, z)))
            house.addChildNode(Shapes.box(0.012, 0.1, 0.18, glass, at: SCNVector3(0.462, 0.84, z)))
        }

        // Deck: grey boards with a wooden rim, on short posts.
        let deckTop: CGFloat = 0.16
        let deckCenter = SCNVector3(-0.1, 0, 0.56)
        c.addChildNode(repeatTexture(Shapes.box(1.1, 0.04, 0.42, deckBoards, texture: Textures.planks,
                                                at: SCNVector3(deckCenter.x, deckTop - 0.04, deckCenter.z)), 1, 4))
        c.addChildNode(Shapes.box(1.12, 0.07, 0.025, deckRim, texture: Textures.planks, at: SCNVector3(-0.1, deckTop - 0.08, 0.78)))
        c.addChildNode(Shapes.box(0.025, 0.07, 0.44, deckRim, texture: Textures.planks, at: SCNVector3(-0.66, deckTop - 0.08, 0.56)))
        c.addChildNode(Shapes.box(0.025, 0.07, 0.44, deckRim, texture: Textures.planks, at: SCNVector3(0.46, deckTop - 0.08, 0.56)))
        for x: CGFloat in [-0.62, 0.42] {
            for z: CGFloat in [0.4, 0.74] {
                c.addChildNode(Shapes.post(radius: 0.02, height: 0.18, foundation, at: SCNVector3(x, -0.1, z)))
            }
        }
        // Step down on the right.
        c.addChildNode(Shapes.box(0.12, 0.08, 0.2, deckRim, texture: Textures.planks, at: SCNVector3(0.52, 0.0, 0.62)))
        c.addChildNode(Shapes.box(0.12, 0.08, 0.2, deckRim, texture: Textures.planks, at: SCNVector3(0.64, -0.06, 0.62)))

        // Two black lounge chairs and a little round table.
        for (x, turn) in [(-0.5, 0.4), (-0.1, -0.4)] as [(CGFloat, CGFloat)] {
            let chair = makeChair()
            chair.position = SCNVector3(x, deckTop, 0.57)
            chair.eulerAngles.y = turn
            c.addChildNode(chair)
        }
        c.addChildNode(Shapes.post(radius: 0.014, height: 0.14, trim, at: SCNVector3(-0.3, deckTop, 0.6)))
        let tableTop = SCNCylinder(radius: 0.07, height: 0.015)
        tableTop.radialSegmentCount = 10
        tableTop.materials = [IslandBuilder.flatMaterial(trim)]
        let table = SCNNode(geometry: tableTop)
        table.position = SCNVector3(-0.3, deckTop + 0.147, 0.6)
        c.addChildNode(table)
        return c
    }

    /// Triangular cedar walls under the roof, front and back.
    private static func makeGables(halfWidth w: Float, halfDepth d: Float, baseY: Float, peakY: Float) -> SCNNode {
        var mesh = LowPolyMesh()
        mesh.uvScale = 4.4
        for side: Float in [-1, 1] {
            mesh.addTriangle(SIMD3(-w, baseY, side * d), SIMD3(w, baseY, side * d), SIMD3(0, peakY, side * d),
                             outward: SIMD3(0, 0, side))
        }
        return SCNNode(geometry: mesh.makeGeometry(material: IslandBuilder.flatMaterial(cedar, texture: Textures.planks)))
    }

    /// Two metal roof slabs meeting at the ridge, with dark trim along the eaves and ridge.
    private static func makeRoof(wallTop: CGFloat) -> SCNNode {
        let roof = SCNNode()
        let run: CGFloat = 0.56, rise: CGFloat = 0.54, depth: CGFloat = 0.86
        // The roof line sits just above the wall corners, so there is no gap under the eaves.
        let ridgeY = wallTop + 0.02 + 0.45 * rise / run
        let slope = atan2(rise, run)
        let length = (run * run + rise * rise).squareRoot()
        for side: CGFloat in [-1, 1] {
            let geometry = SCNBox(width: length, height: 0.035, length: depth, chamferRadius: 0)
            let material = IslandBuilder.flatMaterial(roofMetal, texture: Textures.metal)
            material.diffuse.contentsTransform = SCNMatrix4MakeScale(1, 3, 1)
            geometry.materials = [material]
            let slab = SCNNode(geometry: geometry)
            slab.position = SCNVector3(side * run / 2, ridgeY - rise / 2, 0)
            slab.eulerAngles.z = -side * slope
            roof.addChildNode(slab)
            roof.addChildNode(Shapes.box(0.03, 0.05, depth + 0.02, trim, at: SCNVector3(side * (run + 0.005), ridgeY - rise - 0.04, 0)))
        }
        roof.addChildNode(Shapes.box(0.07, 0.03, depth + 0.02, trim, at: SCNVector3(0, ridgeY, 0)))
        return roof
    }

    /// A black lounge chair: slanted seat and back between two side panels. Faces +z.
    private static func makeChair() -> SCNNode {
        let chair = SCNNode()
        for x: CGFloat in [-0.065, 0.065] {
            chair.addChildNode(Shapes.box(0.014, 0.13, 0.16, trim, at: SCNVector3(x, 0, 0)))
        }
        let seat = Shapes.box(0.13, 0.016, 0.15, trim, at: SCNVector3(0, 0.1, 0.01))
        seat.eulerAngles.x = -0.12
        chair.addChildNode(seat)
        let back = Shapes.box(0.13, 0.17, 0.016, trim, at: SCNVector3(0, 0.1, -0.07))
        back.eulerAngles.x = -0.35
        chair.addChildNode(back)
        return chair
    }
}
