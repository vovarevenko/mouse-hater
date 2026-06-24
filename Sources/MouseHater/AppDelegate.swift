// Copyright © 2026 Vova Revenko

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, HotkeyMonitorDelegate {
    private let settings = Settings()
    private let overlay = OverlayController()
    private var hotkey: HotkeyMonitor!
    private var status: StatusBarController!
    private var accessibilityTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = StatusBarController(settings: settings)
        status.onMenuOpen = { [weak self] in
            self?.refreshAccessibility(promptIfNeeded: false)
        }

        hotkey = HotkeyMonitor(settings: settings)
        hotkey.delegate = self
        overlay.onDeactivate = { [weak self] in self?.hotkey.resetTriggerState() }

        bootstrapLoginItem()
        bootstrapAccessibility()
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityTimer?.invalidate()
        hotkey.stop()
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
        refreshAccessibility(promptIfNeeded: true)

        accessibilityTimer?.invalidate()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0,
                                                  repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshAccessibility(promptIfNeeded: false)
            }
        }
    }

    private func refreshAccessibility(promptIfNeeded: Bool) {
        let trusted = HotkeyMonitor.isAccessibilityTrusted(prompt: promptIfNeeded)

        guard trusted else {
            hotkey.stop()
            overlay.dismiss()
            status.updateAccess(.notGranted)
            return
        }

        if hotkey.start() {
            status.updateAccess(.granted)
        } else {
            overlay.dismiss()
            status.updateAccess(.unavailable)
        }
    }
}
