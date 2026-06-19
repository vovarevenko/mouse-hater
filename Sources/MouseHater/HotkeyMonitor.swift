// Copyright © 2026 Vova Revenko

import ApplicationServices
import CoreGraphics
import QuartzCore

protocol HotkeyMonitorDelegate: AnyObject {
    var overlayIsActive: Bool { get }
    func hotkeyTriggered()
    /// Returns `true` if the key was consumed by the overlay.
    func overlayHandleKey(_ key: OverlayKey, shift: Bool) -> Bool
    /// A key release while the overlay is open (used to commit a held nudge).
    func overlayHandleKeyUp(_ keycode: Int64)
}

/// A session-level `CGEventTap` that does two jobs:
///   1. While the overlay is closed, watches for the Command trigger.
///   2. While the overlay is open, intercepts the keyboard so navigation keys
///      drive the grid instead of leaking into the focused app.
final class HotkeyMonitor {
    weak var delegate: HotkeyMonitorDelegate?

    private let settings: Settings
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Trigger-detection state.
    private var commandDown = false
    private var commandDownAt: CFTimeInterval = 0
    private var tapCandidate = false          // a clean Command press, still eligible
    private var lastTapAt: CFTimeInterval = 0  // for double-tap detection
    private var otherKeysDown = 0             // physical non-modifier keys held down

    /// Keycodes whose keyDown we swallowed while the overlay was active, so we
    /// can swallow the matching keyUp too — even after the overlay dismisses
    /// (dismiss happens synchronously inside the keyDown callback, before the
    /// physical key is released). Self-draining: each keyUp removes its code.
    private var swallowedKeys = Set<Int64>()

    private let tapMaxDuration: CFTimeInterval = 0.3
    private let doubleTapGap: CFTimeInterval = 0.4

    private static let escapeKeyCode: Int64 = 53
    private static let spaceKeyCode: Int64 = 49

    init(settings: Settings) {
        self.settings = settings
    }

    // MARK: - Tap lifecycle

    /// Creates and enables the tap. Returns `false` if Accessibility access has
    /// not been granted yet (the tap can't be created). Safe to call repeatedly.
    @discardableResult
    func start() -> Bool {
        if eventTap != nil { return true }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    static func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Clears in-flight trigger detection (called when the overlay closes).
    func resetTriggerState() {
        commandDown = false
        tapCandidate = false
        lastTapAt = 0
        otherKeysDown = 0
        // Intentionally NOT clearing swallowedKeys: a keyUp pending after dismiss
        // still needs to be swallowed.
    }

    // MARK: - Event handling

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system can silently disable the tap; re-enable and move on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            // Key/flag events fired while the tap was off are lost, so any tracked
            // state is now unreliable — clear the swallow set (to avoid a stranded
            // keycode swallowing a later keyUp in another app) and the trigger
            // state (so a stale commandDown/commandDownAt can't desync detection).
            swallowedKeys.removeAll()
            resetTriggerState()
            return Unmanaged.passUnretained(event)
        }

        if delegate?.overlayIsActive == true {
            return handleWhileActive(type: type, event: event)
        }

        // Inactive: swallow the keyUp of any key whose keyDown we ate while the
        // overlay was up. Dismiss can happen during the keyDown, so the matching
        // keyUp arrives here and would otherwise leak downstream.
        if type == .keyUp {
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            if swallowedKeys.remove(keycode) != nil { return nil }
        }

        detectTrigger(type: type, event: event)
        return Unmanaged.passUnretained(event)
    }

    /// Modal: the overlay owns the keyboard. Every key is swallowed and routed
    /// to the controller, which acts on valid keys and ignores the rest.
    private func handleWhileActive(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .keyDown:
            // Remember this key so its eventual keyUp is swallowed too.
            swallowedKeys.insert(event.getIntegerValueField(.keyboardEventKeycode))
            let shift = event.flags.contains(.maskShift)
            // Keys that aren't valid for the current stage are ignored by the
            // controller (still consumed); Escape cancels.
            _ = delegate?.overlayHandleKey(mapKey(event), shift: shift)
            return nil
        case .keyUp:
            // Matched its swallowed keyDown; route it (commits a held nudge).
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            swallowedKeys.remove(keycode)
            delegate?.overlayHandleKeyUp(keycode)
            return nil
        case .flagsChanged:
            // Pressing Command again closes the overlay (same as Escape).
            if event.flags.contains(.maskCommand) {
                _ = delegate?.overlayHandleKey(.escape, shift: false)
            }
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    /// Maps a key event to an `OverlayKey`. Letter/symbol keys are passed as raw
    /// keycodes (by PHYSICAL POSITION — layout-independent: works on QWERTY,
    /// AZERTY, ЙЦУКЕН, …); the controller interprets them per stage.
    private func mapKey(_ event: CGEvent) -> OverlayKey {
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        switch keycode {
        case Self.escapeKeyCode: return .escape
        case Self.spaceKeyCode:  return .space
        default:                 return .keyCode(keycode)
        }
    }

    // MARK: - Trigger detection

    private func detectTrigger(type: CGEventType, event: CGEvent) {
        switch type {
        case .keyDown:
            // Count physically-held keys (ignore auto-repeat so one key counts once).
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                otherKeysDown += 1
            }
            // A real key pressed while Command is held → it's a shortcut, not a tap.
            if commandDown { tapCandidate = false }

        case .keyUp:
            if otherKeysDown > 0 { otherKeysDown -= 1 }

        case .flagsChanged:
            let flags = event.flags
            let commandNow = flags.contains(.maskCommand)
            let otherModifiers = flags.contains(.maskShift)
                || flags.contains(.maskControl)
                || flags.contains(.maskAlternate)

            if commandNow && !commandDown {
                // Command pressed: a clean tap candidate only if nothing else is held.
                commandDown = true
                commandDownAt = CACurrentMediaTime()
                tapCandidate = !otherModifiers && otherKeysDown == 0
            } else if !commandNow && commandDown {
                // Command released — decide whether it was a clean tap.
                commandDown = false
                let duration = CACurrentMediaTime() - commandDownAt
                if tapCandidate && duration <= tapMaxDuration {
                    registerTap()
                }
                tapCandidate = false
            } else if commandNow && otherModifiers {
                // Another modifier joined Command → no longer a clean tap.
                tapCandidate = false
            }

        default:
            break
        }
    }

    private func registerTap() {
        let now = CACurrentMediaTime()
        switch settings.triggerMode {
        case .singleTap:
            fireTrigger()
        case .doubleTap:
            if now - lastTapAt <= doubleTapGap {
                lastTapAt = 0
                fireTrigger()
            } else {
                lastTapAt = now
            }
        }
    }

    private func fireTrigger() {
        delegate?.hotkeyTriggered()
    }
}

// MARK: - C callback bridge

private func eventTapCallback(proxy: CGEventTapProxy,
                              type: CGEventType,
                              event: CGEvent,
                              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return monitor.handle(type: type, event: event)
}
