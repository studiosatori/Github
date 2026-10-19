import AppKit
import SceneKit
import simd

/// A little cat in a blue kimono that walks on two legs between random spots, pausing to look around.
final class Cat {
    let node = SCNNode()

    private let head = SCNNode()
    private let leftLeg = SCNNode()
    private let rightLeg = SCNNode()
    private let leftArm = SCNNode()
    private let rightArm = SCNNode()
    private let tail = SCNNode()

    /// Island units per second.
    private let speed: Float = 0.2
    private let stepDuration = 0.3

    init() {
        build()
        let start = Self.randomSpot()
        node.position = Self.groundPosition(start)
        node.eulerAngles.y = CGFloat(Float.random(in: 0...(2 * Float.pi)))
    }

    func start() {
        wanderToNextSpot()
    }

    // MARK: - Body

    private func build() {
        let fur = Shapes.color(0.95, 0.62, 0.32)
        let cream = Shapes.color(0.98, 0.90, 0.78)
        let kimono = Shapes.color(0.30, 0.40, 0.62)
        let obi = Shapes.color(0.92, 0.80, 0.55)
        let dark = Shapes.color(0.12, 0.10, 0.10)
        let pink = Shapes.color(0.95, 0.60, 0.65)

        // Limbs hang from pivots at the hip and shoulder so they can swing.
        for (leg, x) in [(leftLeg, -0.025), (rightLeg, 0.025)] as [(SCNNode, CGFloat)] {
            leg.position = SCNVector3(x, 0.07, 0)
            leg.addChildNode(Shapes.box(0.032, 0.07, 0.036, fur, at: SCNVector3(0, -0.07, 0)))
            node.addChildNode(leg)
        }
        node.addChildNode(Shapes.box(0.095, 0.10, 0.07, kimono, at: SCNVector3(0, 0.065, 0)))
        node.addChildNode(Shapes.box(0.10, 0.018, 0.075, obi, at: SCNVector3(0, 0.10, 0)))
        for (arm, x) in [(leftArm, -0.06), (rightArm, 0.06)] as [(SCNNode, CGFloat)] {
            arm.position = SCNVector3(x, 0.155, 0)
            arm.addChildNode(Shapes.box(0.026, 0.07, 0.03, kimono, at: SCNVector3(0, -0.07, 0)))
            arm.addChildNode(Shapes.box(0.024, 0.018, 0.026, fur, at: SCNVector3(0, -0.085, 0)))
            node.addChildNode(arm)
        }

        head.position = SCNVector3(0, 0.165, 0)
        head.addChildNode(Shapes.box(0.11, 0.085, 0.09, fur, at: SCNVector3(0, 0, 0)))
        head.addChildNode(Shapes.box(0.05, 0.03, 0.02, cream, at: SCNVector3(0, 0.008, 0.045)))
        head.addChildNode(Shapes.box(0.014, 0.01, 0.01, pink, at: SCNVector3(0, 0.03, 0.055)))
        for x: CGFloat in [-0.025, 0.025] {
            head.addChildNode(Shapes.box(0.014, 0.018, 0.006, dark, at: SCNVector3(x, 0.04, 0.046)))
            head.addChildNode(Shapes.pyramid(0.035, 0.04, 0.025, fur, at: SCNVector3(x * 1.3, 0.085, 0)))
        }
        node.addChildNode(head)

        tail.position = SCNVector3(0, 0.08, -0.035)
        tail.eulerAngles.x = -0.6
        tail.addChildNode(Shapes.box(0.018, 0.12, 0.018, fur, at: SCNVector3(0, 0, 0)))
        node.addChildNode(tail)
        let swish = SCNAction.rotateBy(x: 0, y: 0, z: 0.35, duration: 1.2)
        swish.timingMode = .easeInEaseOut
        tail.runAction(.repeatForever(.sequence([swish, swish.reversed()])))
    }

    // MARK: - Wandering

    private func wanderToNextSpot() {
        let from = SIMD2<Float>(Float(node.position.x), Float(node.position.z))
        var to = from
        for _ in 0..<30 {
            let candidate = Self.randomSpot()
            if simd_distance(from, candidate) > 0.25 && Self.isPathClear(from, candidate) {
                to = candidate
                break
            }
        }

        let walkDuration = Double(max(0.1, simd_distance(from, to) / speed))
        let heading = atan2(to.x - from.x, to.y - from.y)
        let turn = SCNAction.rotateTo(x: 0, y: CGFloat(heading), z: 0, duration: 0.35, usesShortestUnitArc: true)
        // Custom action so the cat follows the curve of the ground.
        let walk = SCNAction.customAction(duration: walkDuration) { node, elapsed in
            let t = Float(elapsed) / Float(walkDuration)
            node.position = Cat.groundPosition(from + (to - from) * t)
        }

        node.runAction(.sequence([
            turn,
            .run { [weak self] _ in self?.setWalking(true) },
            walk,
            .run { [weak self] _ in self?.setWalking(false) },
            .run { [weak self] _ in self?.lookAround() },
            .wait(duration: Double.random(in: 1.5...5)),
            .run { [weak self] _ in self?.wanderToNextSpot() },
        ]))
    }

    private func setWalking(_ walking: Bool) {
        let limbs: [(SCNNode, CGFloat)] = [(leftLeg, 1), (rightLeg, -1), (leftArm, -1), (rightArm, 1)]
        for (limb, phase) in limbs {
            if walking {
                let swing = 0.5 * phase
                let forward = SCNAction.rotateTo(x: swing, y: 0, z: 0, duration: stepDuration / 2)
                let back = SCNAction.rotateTo(x: -swing, y: 0, z: 0, duration: stepDuration)
                let center = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: stepDuration / 2)
                limb.runAction(.repeatForever(.sequence([forward, back, center])), forKey: "walk")
            } else {
                limb.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.15), forKey: "walk")
            }
        }
    }

    private func lookAround() {
        let angle = CGFloat.random(in: 0.3...0.6) * (Bool.random() ? 1 : -1)
        let look = SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.4, usesShortestUnitArc: true)
        let back = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4, usesShortestUnitArc: true)
        look.timingMode = .easeInEaseOut
        back.timingMode = .easeInEaseOut
        head.runAction(.sequence([look, .wait(duration: 0.8), back]))
    }

    // MARK: - Where the cat may go

    private static func groundPosition(_ p: SIMD2<Float>) -> SCNVector3 {
        scnVector(SIMD3(p.x, IslandBuilder.surfaceHeight(atX: p.x, z: p.y), p.y))
    }

    private static func randomSpot() -> SIMD2<Float> {
        for _ in 0..<50 {
            let r = IslandBuilder.grassRadius * Float.random(in: 0...1).squareRoot()
            let angle = Float.random(in: 0...(2 * Float.pi))
            let p = SIMD2(cos(angle) * r * IslandBuilder.stretch.x, sin(angle) * r * IslandBuilder.stretch.z)
            if !Shrine.isBlocked(p, margin: 0.08) { return p }
        }
        return SIMD2(0.3, 0.6)
    }

    /// The top is convex, so only the temple and gate posts can get in the way.
    private static func isPathClear(_ from: SIMD2<Float>, _ to: SIMD2<Float>) -> Bool {
        (0...12).allSatisfy { i in
            !Shrine.isBlocked(from + (to - from) * (Float(i) / 12), margin: 0.06)
        }
    }
}
