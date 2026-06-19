// Copyright © 2026 Vova Revenko
//
// MouseHater — keyboard-driven mouse clicking for macOS.
// Tap (or double-tap) Command to bring up a labelled grid, type a cell's two
// letters and a final key to click — or hold that key to nudge to an exact point.

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Accessory: no Dock icon, no menu, lives in the status bar only.
app.setActivationPolicy(.accessory)
app.run()
