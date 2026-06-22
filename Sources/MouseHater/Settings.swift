// Copyright © 2026 Vova Revenko

import Foundation

/// How the overlay is summoned.
enum TriggerMode: String {
    /// Press and release Command alone, quickly, with nothing pressed in between.
    case singleTap
    /// Two quick Command taps in a row.
    case doubleTap

    var title: String {
        switch self {
        case .singleTap: return "Single Command tap"
        case .doubleTap: return "Double Command tap"
        }
    }
}

/// Thin wrapper over `UserDefaults` for the handful of user preferences.
final class Settings {
    private let defaults = UserDefaults.standard
    private let triggerKey = "triggerMode"
    private let didOfferLoginItemKey = "didOfferLoginItem"

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

    /// Whether we've already done the one-time login-item setup. Guards against
    /// re-registering on every launch, which would override a user who later
    /// turned the login item off.
    var didOfferLoginItem: Bool {
        get { defaults.bool(forKey: didOfferLoginItemKey) }
        set { defaults.set(newValue, forKey: didOfferLoginItemKey) }
    }
}
