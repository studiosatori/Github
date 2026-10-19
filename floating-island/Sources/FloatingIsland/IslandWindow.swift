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

/// Round button in the top-right corner. Drag it to resize the island; the window keeps its shape.
final class ResizeHandle: NSView {
    static let diameter: CGFloat = 26
    static let sizeRange: ClosedRange<CGFloat> = 200...1000

    private(set) var isResizing = false
    private var startMouse = NSPoint.zero
    private var startFrame = NSRect.zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        toolTip = "Drag to resize"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
        NSColor(white: 1, alpha: 0.85).setFill()
        circle.fill()
        NSColor(white: 0, alpha: 0.15).setStroke()
        circle.stroke()

        guard let symbol = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right",
                                   accessibilityDescription: "Resize")?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .semibold)) else { return }
        let size = symbol.size
        symbol.draw(in: NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                               width: size.width, height: size.height),
                    from: .zero, operation: .sourceOver, fraction: 0.6)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        isResizing = true
        startMouse = NSEvent.mouseLocation
        startFrame = window?.frame ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        // Up-right grows, down-left shrinks. The bottom-left corner stays put.
        let mouse = NSEvent.mouseLocation
        let delta = ((mouse.x - startMouse.x) + (mouse.y - startMouse.y)) / 2
        let height = min(Self.sizeRange.upperBound, max(Self.sizeRange.lowerBound, startFrame.height + delta))
        let width = height * startFrame.width / startFrame.height
        window.setFrame(NSRect(origin: startFrame.origin, size: NSSize(width: width, height: height)), display: true)
    }

    override func mouseUp(with event: NSEvent) {
        isResizing = false
    }
}
