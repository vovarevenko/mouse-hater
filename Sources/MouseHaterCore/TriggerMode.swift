// Copyright © 2026 Vova Revenko

/// How the overlay is summoned.
public enum TriggerMode: String {
    /// Press and release Command alone, quickly, with nothing pressed in between.
    case singleTap
    /// Two quick Command taps in a row.
    case doubleTap

    public var title: String {
        switch self {
        case .singleTap: return "Single Command tap"
        case .doubleTap: return "Double Command tap"
        }
    }
}
