import AppKit
import SceneKit

/// The island with its temple and cat, plus camera and lights.
final class IslandScene {
    static let seed: UInt64 = 2026

    let scene = SCNScene()
    let grass: GrassField
    private let topMaterial: SCNMaterial
    private let cat = Cat()
    private var shownCoverage = -1.0

    init(growthSeconds: Double) {
        let island = IslandBuilder.makeIsland(seed: Self.seed)
        topMaterial = island.topMaterial
        grass = GrassField(parent: island.node, seed: Self.seed, growthSeconds: growthSeconds)

        island.node.addChildNode(Landmarks.makeNode())
        island.node.addChildNode(cat.node)
        scene.rootNode.addChildNode(island.node)
        cat.start()

        let camera = SCNCamera()
        camera.fieldOfView = 35
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2.3, 6.8)
        cameraNode.look(at: SCNVector3(0, -0.45, 0))
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 450
        ambient.color = NSColor(srgbRed: 0.80, green: 0.86, blue: 1, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 850
        sun.color = NSColor(srgbRed: 0.94, green: 0.96, blue: 1, alpha: 1)
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-0.9, 0.5, 0)
        scene.rootNode.addChildNode(sunNode)

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
        topMaterial.multiply.contents = IslandBuilder.dirtColor.blended(withFraction: mix, of: IslandBuilder.meadowColor)
            ?? IslandBuilder.meadowColor
    }
}
