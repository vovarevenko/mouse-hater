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

        bootstrapLoginItem()
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

    // MARK: - Login item

    /// A menu-bar agent is useless when it isn't running, so opt into launch-at-
    /// login on the very first launch. This runs exactly once: afterward the
    /// user's choice (here or in System Settings) is theirs to keep.
    private func bootstrapLoginItem() {
        guard !settings.didOfferLoginItem else { return }

        // The user may already have a stake — enabled it themselves, or disabled
        // it in System Settings (.requiresApproval). Either way, stop offering.
        if LoginItem.isEnabled || LoginItem.requiresApproval {
            settings.didOfferLoginItem = true
            return
        }

        // Mark the one-time setup done only once registration actually succeeds,
        // so a transient failure is retried on the next launch instead of being
        // skipped forever.
        if LoginItem.setEnabled(true) {
            settings.didOfferLoginItem = true
        }
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
