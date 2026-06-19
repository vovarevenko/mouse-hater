// Copyright © 2026 Vova Revenko

import AppKit
import SwiftUI

/// The status-bar menu: trigger mode, an Accessibility shortcut, and Quit.
final class StatusBarController: NSObject {
    private let settings: Settings
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private var singleTapItem: NSMenuItem!
    private var doubleTapItem: NSMenuItem!
    private var accessItem: NSMenuItem!

    init(settings: Settings) {
        self.settings = settings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.click.2",
                                   accessibilityDescription: "Mouse Hater")
            button.toolTip = "Mouse Hater"
        }

        buildMenu()
        statusItem.menu = menu
    }

    func updateAccess(granted: Bool) {
        accessItem.title = granted
            ? "Accessibility: granted"
            : "Accessibility: not granted — click to open Settings"
    }

    // MARK: - Menu

    private func buildMenu() {
        let header = NSMenuItem(title: "Trigger", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        singleTapItem = NSMenuItem(title: TriggerMode.singleTap.title,
                                   action: #selector(selectSingleTap),
                                   keyEquivalent: "")
        singleTapItem.target = self
        menu.addItem(singleTapItem)

        doubleTapItem = NSMenuItem(title: TriggerMode.doubleTap.title,
                                   action: #selector(selectDoubleTap),
                                   keyEquivalent: "")
        doubleTapItem.target = self
        menu.addItem(doubleTapItem)

        menu.addItem(.separator())

        let guideItem = NSMenuItem(title: "Keyboard guide…",
                                   action: #selector(showGuide),
                                   keyEquivalent: "")
        guideItem.target = self
        menu.addItem(guideItem)

        menu.addItem(.separator())

        accessItem = NSMenuItem(title: "Accessibility",
                                action: #selector(openAccessibility),
                                keyEquivalent: "")
        accessItem.target = self
        menu.addItem(accessItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Mouse Hater",
                              action: #selector(quit),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        refreshTriggerChecks()
    }

    private func refreshTriggerChecks() {
        singleTapItem.state = settings.triggerMode == .singleTap ? .on : .off
        doubleTapItem.state = settings.triggerMode == .doubleTap ? .on : .off
    }

    @objc private func selectSingleTap() {
        settings.triggerMode = .singleTap
        refreshTriggerChecks()
    }

    @objc private func selectDoubleTap() {
        settings.triggerMode = .doubleTap
        refreshTriggerChecks()
    }

    @objc private func showGuide() {
        let alert = NSAlert()
        alert.messageText = "Mouse Hater — keyboard guide"
        let hosting = NSHostingView(rootView: GuideView())
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        alert.accessoryView = hosting
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func openAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
