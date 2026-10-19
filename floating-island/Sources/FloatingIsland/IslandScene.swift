import AppKit
import SceneKit

/// The island plus camera, lights, and its idle bob and spin.
final class IslandScene {
    static let seed: UInt64 = 2026

    let scene = SCNScene()
    let grass: GrassField
    private let topMaterial: SCNMaterial
    private var shownCoverage = -1.0

    init(growthSeconds: Double) {
        let island = IslandBuilder.makeIsland(seed: Self.seed)
        topMaterial = island.topMaterial
        grass = GrassField(parent: island.node, seed: Self.seed, growthSeconds: growthSeconds)

        let root = SCNNode()
        root.addChildNode(island.node)
        scene.rootNode.addChildNode(root)

        let camera = SCNCamera()
        camera.fieldOfView = 35
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2.4, 6.2)
        cameraNode.look(at: SCNVector3(0, -0.5, 0))
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 450
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 850
        sun.color = NSColor(srgbRed: 1, green: 0.96, blue: 0.88, alpha: 1)
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-0.9, 0.5, 0)
        scene.rootNode.addChildNode(sunNode)

        let rise = SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 2.5)
        let fall = SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 2.5)
        rise.timingMode = .easeInEaseOut
        fall.timingMode = .easeInEaseOut
        root.runAction(.repeatForever(.sequence([rise, fall])))
        island.node.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 90)))

        refreshTopColor()
    }

    func advance(by dt: Double) {
        grass.advance(by: dt)
        refreshTopColor()
    }

    func reset() {
        grass.reset()
        refreshTopColor()
    }

    private func refreshTopColor() {
        let coverage = grass.coverage
        guard coverage != shownCoverage else { return }
        shownCoverage = coverage
        // The ground turns green a bit ahead of the grass, so it reads as a meadow sooner.
        let mix = CGFloat(min(1, coverage * 1.4))
        topMaterial.diffuse.contents = IslandBuilder.dirtColor.blended(withFraction: mix, of: IslandBuilder.meadowColor)
            ?? IslandBuilder.meadowColor
    }
}
