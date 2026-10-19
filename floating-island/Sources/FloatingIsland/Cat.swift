import AppKit
import SceneKit
import simd

/// A chubby cream-and-orange tabby in a blue shirt and orange overalls.
/// She's very chill: mostly sits or stands around, blinking and looking about,
/// and now and then takes a short, slow walk.
final class Cat {
    let node = SCNNode()

    /// Everything above the legs; it sways side to side while she walks and drops when she sits.
    private let body = SCNNode()
    private let head = SCNNode()
    private var eyes: [SCNNode] = []
    private let leftLeg = SCNNode()
    private let rightLeg = SCNNode()
    private let leftArm = SCNNode()
    private let rightArm = SCNNode()
    private var isSitting = false

    private static let hipHeight: CGFloat = 0.15
    private static let legX: CGFloat = 0.085

    /// Island units per second: a slow stroll.
    private let speed: Float = 0.08
    private let stepDuration = 0.6

    init() {
        build()
        node.scale = SCNVector3(0.6, 0.6, 0.6)
        node.position = Self.groundPosition(Self.randomSpot())
        node.eulerAngles.y = CGFloat(Float.random(in: 0...(2 * Float.pi)))
    }

    func start() {
        doNextThing()
    }

    // MARK: - Body

    private func build() {
        let white = Shapes.color(0.99, 0.98, 0.96)
        let cream = Shapes.color(0.99, 0.88, 0.70)
        let ginger = Shapes.color(0.90, 0.58, 0.30)
        let shirt = Shapes.color(0.42, 0.58, 0.80)
        let shirtLight = Shapes.color(0.60, 0.72, 0.88)
        let overalls = Shapes.color(0.86, 0.55, 0.24)
        let button = Shapes.color(0.40, 0.26, 0.14)
        let green = Shapes.color(0.48, 0.64, 0.26)
        let dark = Shapes.color(0.08, 0.07, 0.07)
        let pink = Shapes.color(0.95, 0.62, 0.62)
        let tabby = Textures.tabby

        // Short legs in overall trousers, with white feet, hanging from hip pivots so they can swing.
        for (leg, x) in [(leftLeg, -Self.legX), (rightLeg, Self.legX)] {
            leg.position = SCNVector3(x, Self.hipHeight, 0)
            leg.addChildNode(Shapes.capsule(radius: 0.058, height: 0.16, overalls, at: SCNVector3(0, -0.06, 0)))
            leg.addChildNode(Shapes.sphere(radius: 0.06, white, at: SCNVector3(0, -0.13, 0.02), scale: SCNVector3(1, 0.6, 1.3)))
            node.addChildNode(leg)
        }
        node.addChildNode(body)

        // Round tummy in a blue shirt, with the overalls over the bottom half.
        body.addChildNode(Shapes.sphere(radius: 0.2, shirt, at: SCNVector3(0, 0.3, 0), scale: SCNVector3(1, 1.05, 0.9)))
        body.addChildNode(Shapes.sphere(radius: 0.205, overalls, at: SCNVector3(0, 0.22, 0), scale: SCNVector3(1, 0.6, 0.92)))
        // Bib, straps over the shoulders, and buttons.
        let bib = Shapes.box(0.17, 0.12, 0.02, overalls, at: SCNVector3(0, 0.25, 0.168))
        bib.eulerAngles.x = -0.25
        body.addChildNode(bib)
        for x: CGFloat in [-0.075, 0.075] {
            for side: CGFloat in [1, -1] {
                let strap = Shapes.box(0.035, 0.17, 0.02, overalls, at: SCNVector3(x, 0.3, side * 0.155))
                strap.eulerAngles.x = -0.45 * side
                body.addChildNode(strap)
            }
            body.addChildNode(Shapes.sphere(radius: 0.016, button, at: SCNVector3(x, 0.355, 0.165)))
        }
        // Collar.
        for x: CGFloat in [-1, 1] {
            let collar = Shapes.pyramid(0.07, 0.06, 0.02, shirtLight, at: SCNVector3(x * 0.045, 0.5, 0.1))
            collar.eulerAngles.x = .pi
            collar.eulerAngles.z = x * 0.4
            body.addChildNode(collar)
        }

        // Arms: blue sleeves rolled up to a light cuff, then a white paw. The inner node swings.
        for (arm, x) in [(leftArm, -0.19), (rightArm, 0.19)] as [(SCNNode, CGFloat)] {
            let shoulder = SCNNode()
            shoulder.position = SCNVector3(x, 0.42, 0)
            shoulder.eulerAngles.z = x < 0 ? -0.35 : 0.35
            arm.addChildNode(Shapes.capsule(radius: 0.048, height: 0.12, shirt, at: SCNVector3(0, -0.03, 0)))
            arm.addChildNode(Shapes.sphere(radius: 0.05, shirtLight, at: SCNVector3(0, -0.08, 0), scale: SCNVector3(1, 0.45, 1)))
            arm.addChildNode(Shapes.sphere(radius: 0.045, white, at: SCNVector3(0, -0.125, 0)))
            shoulder.addChildNode(arm)
            body.addChildNode(shoulder)
        }

        // Big round cream head: white muzzle, big green eyes, ginger stripes on the forehead.
        head.position = SCNVector3(0, 0.62, 0)
        head.addChildNode(Shapes.sphere(radius: 0.17, cream, at: SCNVector3(0, 0, 0), scale: SCNVector3(1.15, 0.95, 1)))
        head.addChildNode(Shapes.sphere(radius: 0.075, white, at: SCNVector3(0, -0.05, 0.12), scale: SCNVector3(1.35, 0.8, 0.6)))
        head.addChildNode(Shapes.sphere(radius: 0.016, pink, at: SCNVector3(0, -0.02, 0.165), scale: SCNVector3(1.2, 0.8, 0.7)))
        for x: CGFloat in [-1, 1] {
            let eye = SCNNode()
            eye.position = SCNVector3(x * 0.068, 0.03, 0.142)
            eye.addChildNode(Shapes.sphere(radius: 0.034, green, at: SCNVector3(0, 0, 0), scale: SCNVector3(1, 1.1, 0.5)))
            eye.addChildNode(Shapes.sphere(radius: 0.02, dark, at: SCNVector3(0, 0, 0.012), scale: SCNVector3(1, 1.2, 0.5)))
            eye.addChildNode(Shapes.sphere(radius: 0.009, .white, at: SCNVector3(-0.008, 0.012, 0.02)))
            head.addChildNode(eye)
            eyes.append(eye)

            let ear = Shapes.pyramid(0.1, 0.11, 0.06, cream, at: SCNVector3(x * 0.1, 0.11, 0))
            let innerEar = Shapes.pyramid(0.055, 0.07, 0.02, pink, at: SCNVector3(x * 0.1, 0.12, 0.022))
            ear.eulerAngles.z = -x * 0.3
            innerEar.eulerAngles.z = -x * 0.3
            head.addChildNode(ear)
            head.addChildNode(innerEar)
            // Ginger cheek stripes.
            let cheek = Shapes.box(0.05, 0.014, 0.01, ginger, at: SCNVector3(x * 0.17, -0.01, 0.07))
            cheek.eulerAngles.y = x * 0.9
            head.addChildNode(cheek)
        }
        for x: CGFloat in [-0.04, 0, 0.04] {
            let stripe = Shapes.box(0.02, 0.06, 0.01, ginger, at: SCNVector3(x, 0.075, 0.128))
            stripe.eulerAngles.x = -0.6
            head.addChildNode(stripe)
        }
        body.addChildNode(head)

        // Striped tail curling up behind her, swishing lazily.
        let tailMount = SCNNode()
        tailMount.position = SCNVector3(0, 0.2, -0.17)
        tailMount.eulerAngles.x = -0.9
        let tail = SCNNode()
        tail.addChildNode(Shapes.capsule(radius: 0.038, height: 0.3, .white, texture: tabby, at: SCNVector3(0, 0.13, 0)))
        tailMount.addChildNode(tail)
        body.addChildNode(tailMount)
        let swish = SCNAction.rotateBy(x: 0, y: 0, z: 0.3, duration: 2.2)
        swish.timingMode = .easeInEaseOut
        tail.runAction(.repeatForever(.sequence([swish, swish.reversed()])))
    }

    // MARK: - Behavior

    /// Mostly sitting or standing around; sometimes a short stroll.
    private func doNextThing() {
        let roll = Float.random(in: 0..<1)
        let again = SCNAction.run { [weak self] _ in self?.doNextThing() }
        if roll < 0.45 {
            node.runAction(.sequence([setSitting(true), idle(for: .random(in: 12...30)), again]))
        } else if roll < 0.75 {
            node.runAction(.sequence([setSitting(false), idle(for: .random(in: 6...14)), again]))
        } else {
            // The stroll calls doNextThing itself once she arrives.
            node.runAction(.sequence([setSitting(false), stroll()]))
        }
    }

    /// Waits, blinking and glancing around now and then.
    private func idle(for duration: Double) -> SCNAction {
        var steps: [SCNAction] = []
        var remaining = duration
        while remaining > 0 {
            let pause = min(remaining, .random(in: 2...5))
            steps.append(.wait(duration: pause))
            remaining -= pause
            let roll = Float.random(in: 0..<1)
            if roll < 0.45 {
                steps.append(.run { [weak self] _ in self?.blink() })
            } else if roll < 0.7 {
                steps.append(.run { [weak self] _ in self?.lookAround() })
            }
        }
        return .sequence(steps)
    }

    /// Sits down (legs out in front, tummy on the ground) or stands back up.
    private func setSitting(_ sitting: Bool) -> SCNAction {
        let duration = 0.9
        return .sequence([
            .run { [weak self] _ in
                guard let self, self.isSitting != sitting else { return }
                self.isSitting = sitting
                let drop: CGFloat = sitting ? -0.09 : 0
                let move = SCNAction.move(to: SCNVector3(0, drop, 0), duration: duration)
                move.timingMode = .easeInEaseOut
                self.body.runAction(move)
                for (leg, x) in [(self.leftLeg, -Self.legX), (self.rightLeg, Self.legX)] {
                    let pose = SCNAction.group([
                        .move(to: SCNVector3(x, Self.hipHeight + drop, sitting ? 0.03 : 0), duration: duration),
                        .rotateTo(x: sitting ? -1.4 : 0, y: 0, z: 0, duration: duration),
                    ])
                    pose.timingMode = .easeInEaseOut
                    leg.runAction(pose)
                }
                for arm in [self.leftArm, self.rightArm] {
                    arm.runAction(.rotateTo(x: sitting ? -0.3 : 0, y: 0, z: 0, duration: duration))
                }
            },
            .wait(duration: duration),
        ])
    }

    /// A short, slow walk to a nearby spot.
    private func stroll() -> SCNAction {
        .run { [weak self] node in
            guard let self else { return }
            let from = SIMD2<Float>(Float(node.position.x), Float(node.position.z))
            var to = from
            for _ in 0..<30 {
                let candidate = Self.randomSpot()
                let distance = simd_distance(from, candidate)
                if distance > 0.2 && distance < 0.8 && Self.isPathClear(from, candidate) {
                    to = candidate
                    break
                }
            }
            let walkDuration = Double(max(0.1, simd_distance(from, to) / self.speed))
            let heading = atan2(to.x - from.x, to.y - from.y)
            let turn = SCNAction.rotateTo(x: 0, y: CGFloat(heading), z: 0, duration: 1.0, usesShortestUnitArc: true)
            turn.timingMode = .easeInEaseOut
            // Custom action so she follows the curve of the ground.
            let walk = SCNAction.customAction(duration: walkDuration) { node, elapsed in
                let t = Float(elapsed) / Float(walkDuration)
                node.position = Cat.groundPosition(from + (to - from) * t)
            }
            node.runAction(.sequence([
                turn,
                .run { [weak self] _ in self?.setWalking(true) },
                walk,
                .run { [weak self] _ in self?.setWalking(false) },
                .run { [weak self] _ in self?.doNextThing() },
            ]))
        }
    }

    private func setWalking(_ walking: Bool) {
        let limbs: [(SCNNode, CGFloat)] = [(leftLeg, 0.3), (rightLeg, -0.3), (leftArm, -0.35), (rightArm, 0.35)]
        for (limb, swing) in limbs {
            if walking {
                let forward = SCNAction.rotateTo(x: swing, y: 0, z: 0, duration: stepDuration / 2)
                let back = SCNAction.rotateTo(x: -swing, y: 0, z: 0, duration: stepDuration)
                let center = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: stepDuration / 2)
                limb.runAction(.repeatForever(.sequence([forward, back, center])), forKey: "walk")
            } else {
                limb.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.3), forKey: "walk")
            }
        }
        if walking {
            let left = SCNAction.rotateTo(x: 0, y: 0, z: 0.05, duration: stepDuration)
            let right = SCNAction.rotateTo(x: 0, y: 0, z: -0.05, duration: stepDuration)
            left.timingMode = .easeInEaseOut
            right.timingMode = .easeInEaseOut
            body.runAction(.repeatForever(.sequence([left, right])), forKey: "walk")
        } else {
            body.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.3), forKey: "walk")
        }
    }

    private func blink() {
        for eye in eyes {
            eye.runAction(.sequence([
                .run { $0.scale = SCNVector3(1, 0.15, 1) },
                .wait(duration: 0.14),
                .run { $0.scale = SCNVector3(1, 1, 1) },
            ]))
        }
    }

    private func lookAround() {
        let angle = CGFloat.random(in: 0.3...0.6) * (Bool.random() ? 1 : -1)
        let look = SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.9, usesShortestUnitArc: true)
        let back = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.9, usesShortestUnitArc: true)
        look.timingMode = .easeInEaseOut
        back.timingMode = .easeInEaseOut
        head.runAction(.sequence([look, .wait(duration: .random(in: 1...2.5)), back]))
    }

    // MARK: - Where the cat may go

    private static func groundPosition(_ p: SIMD2<Float>) -> SCNVector3 {
        scnVector(SIMD3(p.x, IslandBuilder.surfaceHeight(atX: p.x, z: p.y), p.y))
    }

    private static func randomSpot() -> SIMD2<Float> {
        for _ in 0..<50 {
            let r = IslandBuilder.grassRadius * 0.9 * Float.random(in: 0...1).squareRoot()
            let angle = Float.random(in: 0...(2 * Float.pi))
            let p = SIMD2(cos(angle) * r * IslandBuilder.stretch.x, sin(angle) * r * IslandBuilder.stretch.z)
            if !Landmarks.isBlocked(p, margin: 0.15) { return p }
        }
        return SIMD2(0.2, 0.7)
    }

    /// The top is convex, so only the cabin can get in the way.
    private static func isPathClear(_ from: SIMD2<Float>, _ to: SIMD2<Float>) -> Bool {
        (0...16).allSatisfy { i in
            !Landmarks.isBlocked(from + (to - from) * (Float(i) / 16), margin: 0.13)
        }
    }
}
