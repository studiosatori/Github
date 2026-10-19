import Foundation
import SceneKit

/// The idle mechanic: a new tuft sprouts every `sproutInterval` seconds and grows to full size.
/// Everything is derived from `growthSeconds`, so saving that one number saves the island.
final class GrassField {
    static let maxTufts = 800
    static let sproutInterval: Double = 1.75
    static let growDuration: Double = 30

    private(set) var growthSeconds: Double
    private let parent: SCNNode
    private let seed: UInt64
    private let geometries: [SCNGeometry]
    private var tufts: [(node: SCNNode, sproutTime: Double, fullScale: Float)] = []

    init(parent: SCNNode, seed: UInt64, growthSeconds: Double) {
        self.parent = parent
        self.seed = seed
        self.growthSeconds = max(0, growthSeconds)
        geometries = IslandBuilder.makeTuftGeometries(seed: seed &+ 1, count: 6)
        advance(by: 0)
    }

    var sproutedCount: Int { min(Self.maxTufts, Int(growthSeconds / Self.sproutInterval) + 1) }
    var coverage: Double { Double(sproutedCount) / Double(Self.maxTufts) }

    func advance(by dt: Double) {
        growthSeconds += dt
        while tufts.count < sproutedCount {
            sprout(index: tufts.count)
        }
        // Only tufts still growing need a new scale; one extra settles the one that just finished.
        let firstGrowing = max(0, Int((growthSeconds - Self.growDuration) / Self.sproutInterval) - 1)
        for i in min(firstGrowing, tufts.count)..<tufts.count {
            applyGrowth(to: i)
        }
    }

    func reset() {
        tufts.forEach { $0.node.removeFromParentNode() }
        tufts.removeAll()
        growthSeconds = 0
        advance(by: 0)
    }

    private func sprout(index: Int) {
        var rng = SeededRandom(seed: seed &+ UInt64(index) &* 1_000_003)
        // Pick a spot that isn't under the temple.
        var spot = SIMD2<Float>(0, 0)
        for _ in 0..<20 {
            let r = IslandBuilder.grassRadius * rng.float(0...1).squareRoot()
            let angle = rng.float(0...(2 * Float.pi))
            spot = SIMD2(cos(angle) * r * IslandBuilder.stretch.x, sin(angle) * r * IslandBuilder.stretch.z)
            if !Landmarks.isBlocked(spot, margin: 0.04) { break }
        }
        let node = SCNNode(geometry: geometries[Int(rng.next() % UInt64(geometries.count))])
        node.position = scnVector(SIMD3(spot.x, IslandBuilder.surfaceHeight(atX: spot.x, z: spot.y) - 0.02, spot.y))
        node.eulerAngles.y = CGFloat(rng.float(0...(2 * Float.pi)))
        parent.addChildNode(node)
        tufts.append((node, Double(index) * Self.sproutInterval, rng.float(0.75...1.2)))
        applyGrowth(to: index)

        // A gentle sway in the breeze.
        let sway = CGFloat(rng.float(0.05...0.1))
        let duration = Double(rng.float(1.4...2.2))
        let lean = SCNAction.rotateBy(x: sway, y: 0, z: 0, duration: duration)
        let back = SCNAction.rotateBy(x: -sway, y: 0, z: 0, duration: duration)
        lean.timingMode = .easeInEaseOut
        back.timingMode = .easeInEaseOut
        node.runAction(.sequence([
            .wait(duration: Double(rng.float(0...2))),
            .repeatForever(.sequence([lean, back])),
        ]))
    }

    private func applyGrowth(to index: Int) {
        let tuft = tufts[index]
        let progress = min(1, max(0, (growthSeconds - tuft.sproutTime) / Self.growDuration))
        let eased = 1 - pow(1 - progress, 3)
        let scale = CGFloat(Float(0.05 + 0.95 * eased) * tuft.fullScale)
        tuft.node.scale = SCNVector3(scale, scale, scale)
    }
}
