import AppKit
import SceneKit
import simd

/// The old windmill on top of the island, and the ground it takes up.
enum Landmarks {
    /// Island-space (x, z) position. The camera looks from +z, so the windmill sits toward the back,
    /// turned a little so the sails face the camera at an angle.
    static let windmillPosition = SIMD2<Float>(-0.25, -0.5)
    static let windmillAngle: Float = -0.35

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

    /// Tower, the sacks by the door, and the space under the sails, in the windmill's own frame:
    /// x -0.45...0.45, z -0.42...0.5.
    private static let footprints = [
        Footprint(center: windmillPosition + rotated(SIMD2(0, 0.04), by: windmillAngle),
                  halfSize: SIMD2(0.45, 0.46), angle: windmillAngle),
    ]

    /// Whether something at `p` would bump into the windmill.
    static func isBlocked(_ p: SIMD2<Float>, margin: Float) -> Bool {
        footprints.contains { $0.contains(p, margin: margin) }
    }

    static func makeNode() -> SCNNode {
        let windmill = makeWindmill()
        windmill.position = scnVector(SIMD3(windmillPosition.x,
                                            IslandBuilder.surfaceHeight(atX: windmillPosition.x, z: windmillPosition.y),
                                            windmillPosition.y))
        windmill.eulerAngles.y = CGFloat(windmillAngle)
        return windmill
    }

    private static let stone = SIMD3<Float>(0.62, 0.58, 0.52)
    private static let plaster = SIMD3<Float>(0.84, 0.74, 0.62)
    private static let roofTiles = Shapes.color(0.62, 0.40, 0.28)
    private static let oldWood = Shapes.color(0.38, 0.26, 0.18)
    private static let shadow = Shapes.color(0.10, 0.08, 0.07)
    private static let burlap = Shapes.color(0.86, 0.78, 0.62)

    private static let towerHeight: Float = 1.05
    private static let sides = 10

    /// Tower radius at height `y`: it narrows toward the top.
    private static func towerRadius(at y: Float) -> Float {
        0.38 - 0.1 * max(0, y) / towerHeight
    }

    /// Worn windmill: stone base, plastered tower, conical tiled roof, small windows, an arched door,
    /// and four lattice sails that turn slowly. Faces +z.
    private static func makeWindmill() -> SCNNode {
        let w = SCNNode()
        w.addChildNode(makeTower())
        w.addChildNode(makeRoof())

        // Arched doorway in the stone base.
        let doorZ = CGFloat(towerRadius(at: 0.15) * cos(.pi / Float(sides))) + 0.005
        w.addChildNode(Shapes.box(0.2, 0.32, 0.03, shadow, at: SCNVector3(0, -0.02, doorZ)))
        let arch = SCNNode(geometry: SCNCylinder(radius: 0.1, height: 0.03))
        arch.geometry?.materials = [IslandBuilder.flatMaterial(shadow)]
        arch.position = SCNVector3(0, 0.3, doorZ - 0.003)
        arch.eulerAngles.x = .pi / 2
        w.addChildNode(arch)
        w.addChildNode(Shapes.box(0.24, 0.025, 0.06, oldWood, at: SCNVector3(0, -0.02, doorZ + 0.01)))

        // Small square windows dotted around the plaster.
        for (angle, y) in [(Float.pi / 2 - 0.5, 0.62), (Float.pi / 2 + 0.7, 0.82), (Float.pi / 2 - 1.6, 0.78), (Float.pi / 2, 0.88)]
            as [(Float, Float)] {
            let r = towerRadius(at: y) * cos(.pi / Float(sides)) + 0.005
            let window = Shapes.box(0.06, 0.08, 0.02, shadow, at: scnVector(SIMD3(cos(angle) * r, y, sin(angle) * r)))
            window.eulerAngles.y = CGFloat(Float.pi / 2 - angle)
            w.addChildNode(window)
        }

        w.addChildNode(makeSails())

        // Flour sacks and an old crate by the door.
        w.addChildNode(Shapes.sphere(radius: 0.06, burlap, at: SCNVector3(0.25, 0.04, 0.36), scale: SCNVector3(1, 1.2, 0.9)))
        w.addChildNode(Shapes.sphere(radius: 0.05, burlap, at: SCNVector3(0.33, 0.03, 0.3), scale: SCNVector3(1, 1.1, 0.9)))
        let crate = Shapes.box(0.12, 0.1, 0.12, oldWood, texture: Textures.planks, at: SCNVector3(-0.27, -0.01, 0.34))
        crate.eulerAngles.y = 0.3
        w.addChildNode(crate)
        return w
    }

    /// Ring of points around the tower axis; one face of each ring points straight at +z.
    private static func ring(y: Float, radius: Float, jitter: Float, rng: inout SeededRandom) -> [SIMD3<Float>] {
        (0..<sides).map { k in
            let a = Float(k) / Float(sides) * 2 * .pi + .pi / 2 - .pi / Float(sides)
            let r = radius + rng.float(-jitter...jitter)
            return SIMD3(cos(a) * r, y, sin(a) * r)
        }
    }

    private static func makeTower() -> SCNNode {
        var rng = SeededRandom(seed: 31)
        let rings = [-0.12, 0.18, 0.36, 0.7, towerHeight].map { y in
            ring(y: y, radius: towerRadius(at: y), jitter: y > 0 ? 0.008 : 0, rng: &rng)
        }
        // Rough stone blocks at the bottom, worn plaster above with a few grimy patches.
        var stoneMesh = LowPolyMesh()
        stoneMesh.uvScale = 6
        var plasterMesh = LowPolyMesh()
        plasterMesh.uvScale = 2
        for level in 0..<rings.count - 1 {
            let lower = rings[level], upper = rings[level + 1]
            let isStone = level < 2
            for i in 0..<sides {
                let j = (i + 1) % sides
                let grime: Float = !isStone && rng.float(0...1) < 0.25 ? 0.82 : 1
                let color = vertexColor(isStone ? stone : plaster, shade: grime * rng.float(0.88...1.04))
                if isStone {
                    stoneMesh.addSideTriangle(lower[i], lower[j], upper[j], color: color)
                    stoneMesh.addSideTriangle(lower[i], upper[j], upper[i], color: color)
                } else {
                    plasterMesh.addSideTriangle(lower[i], lower[j], upper[j], color: color)
                    plasterMesh.addSideTriangle(lower[i], upper[j], upper[i], color: color)
                }
            }
        }
        let tower = SCNNode()
        tower.addChildNode(SCNNode(geometry: stoneMesh.makeGeometry(material: IslandBuilder.flatMaterial(.white, texture: Textures.tiles))))
        tower.addChildNode(SCNNode(geometry: plasterMesh.makeGeometry(material: IslandBuilder.flatMaterial(.white, texture: Textures.rock))))
        return tower
    }

    /// Cone of clay tiles with a little overhang and a slightly crooked tip.
    private static func makeRoof() -> SCNNode {
        var rng = SeededRandom(seed: 32)
        let bottom = ring(y: towerHeight - 0.03, radius: 0.34, jitter: 0.01, rng: &rng)
        let top = bottom.map { $0 + SIMD3(0, 0.035, 0) }
        let apex = SIMD3<Float>(0.015, towerHeight + 0.38, -0.01)
        var mesh = LowPolyMesh()
        mesh.uvScale = 5
        func shade() -> SIMD4<Float> { vertexColor(1, 1, 1, shade: rng.float(0.86...1.0)) }
        for i in 0..<sides {
            let j = (i + 1) % sides
            mesh.addSideTriangle(bottom[i], bottom[j], top[j], color: shade())
            mesh.addSideTriangle(bottom[i], top[j], top[i], color: shade())
            let c = (top[i] + top[j] + apex) / 3
            mesh.addTriangle(top[i], top[j], apex, outward: SIMD3(c.x, 0.5, c.z), color: shade())
            mesh.addTriangle(bottom[i], bottom[j], SIMD3(0, towerHeight - 0.03, 0), outward: SIMD3(0, -1, 0))
        }
        return SCNNode(geometry: mesh.makeGeometry(material: IslandBuilder.flatMaterial(roofTiles, texture: Textures.tiles)))
    }

    /// Hub on the front of the tower with four lattice sails; one is torn short. They turn slowly.
    private static func makeSails() -> SCNNode {
        let hubY: Float = 0.92
        let hubZ = CGFloat(towerRadius(at: hubY)) + 0.1
        let axle = Shapes.post(radius: 0.03, height: 0.14, oldWood, at: SCNVector3(0, -0.07, 0))
        let axleMount = SCNNode()
        axleMount.position = SCNVector3(0, CGFloat(hubY), hubZ - 0.07)
        axleMount.eulerAngles.x = .pi / 2
        axleMount.addChildNode(axle)

        let sails = SCNNode()
        sails.position = SCNVector3(0, CGFloat(hubY), hubZ)
        sails.addChildNode(Shapes.sphere(radius: 0.045, oldWood, at: SCNVector3(0, 0, 0)))
        for k in 0..<4 {
            let sail = SCNNode()
            sail.eulerAngles.z = CGFloat(k) * .pi / 2
            let length: CGFloat = k == 2 ? 0.45 : 0.6
            sail.addChildNode(Shapes.box(0.03, 0.8, 0.03, oldWood, at: SCNVector3(0, 0, 0)))
            let canvas = Shapes.box(0.18, length, 0.012, .white, texture: Textures.lattice,
                                    at: SCNVector3(0.1, 0.14, 0.01))
            canvas.geometry?.firstMaterial?.diffuse.contentsTransform = SCNMatrix4MakeScale(1, length / 0.18, 1)
            canvas.geometry?.firstMaterial?.isDoubleSided = true
            sail.addChildNode(canvas)
            sails.addChildNode(sail)
        }
        sails.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: -2 * .pi, duration: 40)))

        let node = SCNNode()
        node.addChildNode(axleMount)
        node.addChildNode(sails)
        return node
    }
}
