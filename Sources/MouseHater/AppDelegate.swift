// Copyright © 2026 Vova Revenko

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, HotkeyMonitorDelegate {
    private let settings = Settings()
    private let overlay = OverlayController()
    private var hotkey: HotkeyMonitor!
    private var status: StatusBarController!
    private var accessTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = StatusBarController(settings: settings)

        hotkey = HotkeyMonitor(settings: settings)
        hotkey.delegate = self
        overlay.onDeactivate = { [weak self] in self?.hotkey.resetTriggerState() }

        bootstrapAccessibility()
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessTimer?.invalidate()
    }

    // MARK: - HotkeyMonitorDelegate

    var overlayIsActive: Bool { overlay.active }

    func hotkeyTriggered() { overlay.toggle() }

    func overlayHandleKey(_ key: OverlayKey, shift: Bool) -> Bool {
        overlay.handleKey(key, shift: shift)
    }

    func overlayHandleKeyUp(_ keycode: Int64) {
        overlay.handleKeyUp(keycode)
    }

    // MARK: - Accessibility

    private func bootstrapAccessibility() {
        if hotkey.start() {
            status.updateAccess(granted: true)
            return
        }

        // Not trusted yet: prompt, then poll until the user grants access.
        HotkeyMonitor.promptAccessibility()
        status.updateAccess(granted: false)
        accessTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { return }
            if self.hotkey.start() {
                self.status.updateAccess(granted: true)
                timer.invalidate()
                self.accessTimer = nil
            }
        }
    }
}
