// Copyright © 2026 Vova Revenko

import ServiceManagement

/// "Open at login" via the system service manager. The state is owned by macOS
/// (visible in System Settings ▸ General ▸ Login Items), not by our defaults —
/// so we read it from, and write it through, `SMAppService.mainApp`.
enum LoginItem {
    /// Whether the app is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// The user disabled us in System Settings; macOS won't let us flip it back
    /// programmatically — they have to re-enable it there.
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Register or unregister the app as a login item. Returns `false` if the
    /// system rejected the change (e.g. the user disabled it in Settings).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }

    /// Open System Settings ▸ General ▸ Login Items so the user can resolve a
    /// change we couldn't make for them.
    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
