// Copyright © 2026 Vova Revenko

import Foundation
import MouseHaterCore

/// Thin wrapper over `UserDefaults` for the handful of user preferences.
final class Settings {
    private let defaults = UserDefaults.standard
    private let triggerKey = "triggerMode"
    private let didCompleteOnboardingKey = "didCompleteOnboarding"

    var triggerMode: TriggerMode {
        get {
            guard let raw = defaults.string(forKey: triggerKey),
                  let mode = TriggerMode(rawValue: raw) else {
                return .singleTap
            }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: triggerKey) }
    }

    /// Whether the first-run setup window has already been completed or closed.
    var didCompleteOnboarding: Bool {
        get { defaults.bool(forKey: didCompleteOnboardingKey) }
        set { defaults.set(newValue, forKey: didCompleteOnboardingKey) }
    }
}
