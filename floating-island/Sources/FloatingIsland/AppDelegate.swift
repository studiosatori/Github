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
    private var islandView: IslandView!
    private var resizeHandle: ResizeHandle!
    private var handleShown = false
    private var statusItem: NSStatusItem!
    private var lastTick = Date()
    private var secondsSinceSave: Double = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        islandScene = IslandScene(growthSeconds: GrowthStore.load())

        islandView = IslandView(frame: NSRect(x: 0, y: 0, width: 504, height: 420))
        islandView.scene = islandScene.scene
        islandView.backgroundColor = .clear
        islandView.layer?.isOpaque = false
        // The pixel look is experimental and off by default; it's switched on from the menu.
        applyPixelLook(UserDefaults.standard.bool(forKey: Self.pixelLookKey))
        islandView.preferredFramesPerSecond = 30
        islandView.menu = makeMenu()

        let inset = ResizeHandle.diameter + 8
        resizeHandle = ResizeHandle(frame: NSRect(x: islandView.bounds.maxX - inset, y: islandView.bounds.maxY - inset,
                                                  width: ResizeHandle.diameter, height: ResizeHandle.diameter))
        resizeHandle.autoresizingMask = [.minXMargin, .minYMargin]
        resizeHandle.alphaValue = 0
        islandView.addSubview(resizeHandle)

        window = IslandWindow(size: islandView.frame.size)
        window.contentView = islandView
        window.setFrameAutosaveName("FloatingIslandWideWindow")
        window.orderFrontRegardless()

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
        menu.item(withTag: Tag.pixelLook)?.state = islandView.technique != nil ? .on : .off
    }

    private static let pixelLookKey = "pixelLook"

    @objc private func togglePixelLook() {
        let on = islandView.technique == nil
        applyPixelLook(on)
        UserDefaults.standard.set(on, forKey: Self.pixelLookKey)
    }

    /// Low-resolution render scaled up with sharp pixels, or the normal smooth render.
    private func applyPixelLook(_ on: Bool) {
        islandView.technique = on ? PixelTechnique.make(device: islandView.device) : nil
        islandView.antialiasingMode = islandView.technique == nil ? .multisampling4X : .none
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
