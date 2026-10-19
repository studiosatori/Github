import AppKit
import SceneKit

/// Frameless, transparent window that floats above other apps on every Space.
final class IslandWindow: NSWindow {
    init(size: NSSize) {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(x: screen.maxX - size.width - 40, y: screen.minY + 40)
        super.init(contentRect: NSRect(origin: origin, size: size),
                   styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false
    }

    // Borderless windows can't become key by default, which would break the right-click menu.
    override var canBecomeKey: Bool { true }
}

/// Dragging anywhere on the island moves the window.
final class IslandView: SCNView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
