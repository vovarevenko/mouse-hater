// Copyright © 2026 Vova Revenko

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, HotkeyMonitorDelegate {
    private let settings = Settings()
    private let overlay = OverlayController()
    private var hotkey: HotkeyMonitor!
    private var status: StatusBarController!
    private var accessibilityTimer: Timer?
    private var onboarding: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = StatusBarController(settings: settings)
        status.onMenuOpen = { [weak self] in
            self?.refreshAccessibility(promptIfNeeded: false)
        }
        status.onRequestAccessibility = { [weak self] in
            self?.requestAccessibilityPermission()
        }
        status.onShowOnboarding = { [weak self] in
            self?.showOnboarding()
        }

        hotkey = HotkeyMonitor(settings: settings)
        hotkey.delegate = self
        overlay.onDeactivate = { [weak self] in self?.hotkey.resetTriggerState() }

        bootstrapAccessibility()
        showOnboardingIfNeeded()
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

    // MARK: - Accessibility

    private func bootstrapAccessibility() {
        refreshAccessibility(promptIfNeeded: false)

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

    private func requestAccessibilityPermission() {
        HotkeyMonitor.promptAccessibility()
        refreshAccessibility(promptIfNeeded: false)
    }

    // MARK: - Onboarding

    private func showOnboardingIfNeeded() {
        guard !settings.didCompleteOnboarding else { return }
        showOnboarding()
    }

    private func showOnboarding() {
        if let onboarding {
            onboarding.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = OnboardingWindowController(
            isLoginItemEnabled: { LoginItem.isEnabled },
            enableLoginItem: { LoginItem.setEnabled(true) },
            openLoginItemSettings: { LoginItem.openSystemSettings() },
            isAccessibilityTrusted: { HotkeyMonitor.isAccessibilityTrusted() },
            requestAccessibility: { [weak self] in self?.requestAccessibilityPermission() },
            onClose: { [weak self] in
                self?.settings.didCompleteOnboarding = true
                self?.onboarding = nil
            })

        onboarding = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
