// Copyright © 2026 Vova Revenko

import Foundation

/// Pure state machine that recognises clean Command taps from keyboard events.
/// Platform-specific event taps translate their events into `Input` values.
public struct CommandTapRecognizer {
    public enum Input {
        case keyDown(isRepeat: Bool)
        case keyUp
        case flagsChanged(command: Bool, otherModifiers: Bool)
    }

    private var commandDown = false
    private var commandDownAt: TimeInterval = 0
    private var tapCandidate = false
    private var lastTapAt: TimeInterval?
    private var otherKeysDown = 0

    private let tapMaxDuration: TimeInterval
    private let doubleTapGap: TimeInterval

    public init(tapMaxDuration: TimeInterval = 0.3,
                doubleTapGap: TimeInterval = 0.4) {
        self.tapMaxDuration = tapMaxDuration
        self.doubleTapGap = doubleTapGap
    }

    public mutating func reset() {
        commandDown = false
        commandDownAt = 0
        tapCandidate = false
        lastTapAt = nil
        otherKeysDown = 0
    }

    /// Consumes one translated keyboard event and returns `true` when the
    /// configured trigger has completed.
    @discardableResult
    public mutating func handle(_ input: Input,
                                at timestamp: TimeInterval,
                                mode: TriggerMode) -> Bool {
        switch input {
        case .keyDown(let isRepeat):
            if !isRepeat {
                otherKeysDown += 1
                lastTapAt = nil
            }
            if commandDown { tapCandidate = false }

        case .keyUp:
            if otherKeysDown > 0 { otherKeysDown -= 1 }

        case .flagsChanged(let commandNow, let otherModifiers):
            if otherModifiers {
                tapCandidate = false
                lastTapAt = nil
            }

            if commandNow && !commandDown {
                commandDown = true
                commandDownAt = timestamp
                tapCandidate = !otherModifiers && otherKeysDown == 0
            } else if !commandNow && commandDown {
                commandDown = false
                let duration = timestamp - commandDownAt
                defer { tapCandidate = false }
                guard tapCandidate, duration <= tapMaxDuration else {
                    lastTapAt = nil
                    return false
                }
                return registerTap(at: timestamp, mode: mode)
            }
        }

        return false
    }

    private mutating func registerTap(at timestamp: TimeInterval,
                                      mode: TriggerMode) -> Bool {
        switch mode {
        case .singleTap:
            return true
        case .doubleTap:
            if let lastTapAt, timestamp - lastTapAt <= doubleTapGap {
                self.lastTapAt = nil
                return true
            }
            lastTapAt = timestamp
            return false
        }
    }
}
