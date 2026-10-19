import AppKit
import SceneKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum Tag {
        static let growth = 1
        static let onTop = 2
        static let pixelLook = 3
    }

    private var islandScene: IslandScene!
    private var window: IslandWindow!
    private var container: IslandContainerView!
    private var islandView: IslandView!
    private var pixelView: PixelView!
    private var pixelRenderer: SCNRenderer?
    private var pixelTimer: Timer?
    private var pixelImage: CGImage?
    private var resizeHandle: ResizeHandle!
    private var handleShown = false
    private var statusItem: NSStatusItem!
    private var lastTick = Date()
    private var secondsSinceSave: Double = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        islandScene = IslandScene(growthSeconds: GrowthStore.load())

        container = IslandContainerView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        container.menu = makeMenu()

        islandView = IslandView(frame: container.bounds)
        islandView.autoresizingMask = [.width, .height]
        islandView.scene = islandScene.scene
        islandView.pointOfView = islandScene.cameraNode
        islandView.backgroundColor = .clear
        islandView.layer?.isOpaque = false
        islandView.antialiasingMode = .multisampling4X
        islandView.preferredFramesPerSecond = 30
        islandView.menu = makeMenu()
        container.addSubview(islandView)

        pixelView = PixelView(frame: container.bounds)
        pixelView.autoresizingMask = [.width, .height]
        pixelView.isHidden = true
        container.addSubview(pixelView)

        let inset = ResizeHandle.diameter + 8
        resizeHandle = ResizeHandle(frame: NSRect(x: container.bounds.maxX - inset, y: container.bounds.maxY - inset,
                                                  width: ResizeHandle.diameter, height: ResizeHandle.diameter))
        resizeHandle.autoresizingMask = [.minXMargin, .minYMargin]
        resizeHandle.alphaValue = 0
        container.addSubview(resizeHandle)

        window = IslandWindow(size: container.frame.size)
        window.contentView = container
        window.setFrameAutosaveName("FloatingIslandWidestWindow")
        window.orderFrontRegardless()
        applyPixelLook(UserDefaults.standard.bool(forKey: Self.pixelLookKey))

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🏝"
        statusItem.menu = makeMenu()

        Timer.scheduledTimer(timeInterval: 1.0 / 15, target: self, selector: #selector(tick),
                             userInfo: nil, repeats: true)
        Timer.scheduledTimer(timeInterval: 1.0 / 20, target: self, selector: #selector(updateClickThrough),
                             userInfo: nil, repeats: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        save()
    }

    // MARK: - Game loop

    @objc private func tick() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        islandScene.advance(by: dt)

        secondsSinceSave += dt
        if secondsSinceSave >= 10 { save() }
    }

    private func save() {
        GrowthStore.save(growthSeconds: islandScene.grass.growthSeconds)
        secondsSinceSave = 0
    }

    /// Clicks on empty, transparent parts of the window fall through to whatever is behind it.
    /// Also shows the resize handle while the mouse is over the window.
    @objc private func updateClickThrough() {
        guard !resizeHandle.isResizing else { return }
        let mouse = NSEvent.mouseLocation
        let overWindow = window.frame.contains(mouse)
        var interactive = false
        if overWindow {
            let windowPoint = window.convertPoint(fromScreen: mouse)
            if resizeHandle.bounds.contains(resizeHandle.convert(windowPoint, from: nil)) {
                interactive = true
            } else if pixelTimer != nil {
                interactive = isDrawnPixel(at: pixelView.convert(windowPoint, from: nil))
            } else {
                let point = islandView.convert(windowPoint, from: nil)
                interactive = !islandView.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.any.rawValue]).isEmpty
            }
        }
        if window.ignoresMouseEvents == interactive {
            window.ignoresMouseEvents = !interactive
        }
        if handleShown != overWindow {
            handleShown = overWindow
            resizeHandle.animator().alphaValue = overWindow ? 1 : 0
        }
    }

    // MARK: - Menu (status bar and right-click)

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let growth = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        growth.tag = Tag.growth
        growth.isEnabled = false
        menu.addItem(growth)
        menu.addItem(.separator())

        let onTop = NSMenuItem(title: "Keep on Top", action: #selector(toggleOnTop), keyEquivalent: "")
        onTop.tag = Tag.onTop
        onTop.target = self
        menu.addItem(onTop)

        let pixelLook = NSMenuItem(title: "Pixel Look (Experimental)", action: #selector(togglePixelLook), keyEquivalent: "")
        pixelLook.tag = Tag.pixelLook
        pixelLook.target = self
        menu.addItem(pixelLook)

        let reset = NSMenuItem(title: "Reset Island", action: #selector(resetIsland), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Floating Island", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(withTag: Tag.growth)?.title = "🌱 Grass: \(islandScene.grass.sproutedCount) / \(GrassField.maxTufts)"
        menu.item(withTag: Tag.onTop)?.state = window.level == .floating ? .on : .off
        menu.item(withTag: Tag.pixelLook)?.state = pixelTimer != nil ? .on : .off
    }

    private static let pixelLookKey = "pixelLook"

    /// Fraction of the window's resolution the pixel look renders at. Smaller means chunkier pixels.
    private static let pixelResolution: CGFloat = 0.5

    @objc private func togglePixelLook() {
        let on = pixelTimer == nil
        applyPixelLook(on)
        UserDefaults.standard.set(on, forKey: Self.pixelLookKey)
    }

    /// Pixel look: the 3D view is hidden, and each frame the scene is rendered offscreen into a small
    /// image that the pixel view shows scaled up with sharp pixels. Off: the normal smooth 3D view.
    private func applyPixelLook(_ on: Bool) {
        pixelTimer?.invalidate()
        pixelTimer = nil
        islandView.isHidden = on
        islandView.isPlaying = !on
        pixelView.isHidden = !on
        guard on else { return }
        if pixelRenderer == nil {
            let renderer = SCNRenderer(device: islandView.device, options: nil)
            renderer.scene = islandScene.scene
            renderer.pointOfView = islandScene.cameraNode
            pixelRenderer = renderer
        }
        renderPixelFrame()
        pixelTimer = Timer.scheduledTimer(timeInterval: 1.0 / 30, target: self, selector: #selector(renderPixelFrame),
                                          userInfo: nil, repeats: true)
    }

    @objc private func renderPixelFrame() {
        guard let renderer = pixelRenderer else { return }
        let scale = window.backingScaleFactor * Self.pixelResolution
        let size = CGSize(width: max(1, (pixelView.bounds.width * scale).rounded()),
                          height: max(1, (pixelView.bounds.height * scale).rounded()))
        let image = renderer.snapshot(atTime: CACurrentMediaTime(), with: size, antialiasingMode: .none)
        pixelImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        pixelView.layer?.contents = pixelImage
    }

    /// Whether the pixel look drew something (not transparent) at this point in the pixel view.
    private func isDrawnPixel(at point: NSPoint) -> Bool {
        guard let image = pixelImage, pixelView.bounds.width > 0, pixelView.bounds.height > 0 else { return false }
        let x = Int(point.x / pixelView.bounds.width * CGFloat(image.width))
        let y = Int(point.y / pixelView.bounds.height * CGFloat(image.height))
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { bytes in
            // Draw the image shifted so the pixel under the mouse lands in a 1×1 bitmap.
            guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.draw(image, in: CGRect(x: -x, y: -y, width: image.width, height: image.height))
        }
        return pixel[3] > 0
    }

    @objc private func toggleOnTop() {
        window.level = window.level == .floating ? .normal : .floating
    }

    @objc private func resetIsland() {
        islandScene.reset()
        save()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Saves progress, and adds the time the app was closed, so grass keeps growing while you're away.
enum GrowthStore {
    private static let growthKey = "growthSeconds"
    private static let lastSeenKey = "lastSeen"
    static let maxOfflineSeconds: Double = 8 * 3600

    static func load() -> Double {
        let defaults = UserDefaults.standard
        var growth = defaults.double(forKey: growthKey)
        if let lastSeen = defaults.object(forKey: lastSeenKey) as? Date {
            growth += min(maxOfflineSeconds, max(0, Date().timeIntervalSince(lastSeen)))
        }
        return growth
    }

    static func save(growthSeconds: Double) {
        let defaults = UserDefaults.standard
        defaults.set(growthSeconds, forKey: growthKey)
        defaults.set(Date(), forKey: lastSeenKey)
    }
}
