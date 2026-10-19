import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Accessory: no Dock icon, no menu bar takeover. The island lives in the status bar.
app.setActivationPolicy(.accessory)
app.run()
