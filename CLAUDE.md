# Mouse Hater

macOS menu-bar agent (`LSUIElement`) for keyboard-driven mouse clicking: a SwiftPM
executable assembled into a `.app` by `build.sh`. Flow: `HotkeyMonitor` (a
`CGEventTap`) detects the Command-tap trigger and feeds keys to `OverlayController`
(selection state machine + geometry), which draws via `OverlayView` and clicks via
`Clicker`.

## Commands

- `swift build` — compile check.
- `./build.sh [debug|release]` — build, assemble, and sign `build/MouseHater.app`
  (release by default); `open` it to run.

## Gotchas

- **Coordinates:** all geometry is in global display coordinates (top-left origin,
  points). The click point goes straight to `Clicker`; only the rect handed to the
  flipped `OverlayView` is offset by the display origin. Don't introduce AppKit's
  bottom-left coordinates.
- **Key matching is by virtual keycode (physical position), not character** — keep
  it keyboard-layout-independent.
- **The `CGEventTap`** lives on the main run loop, must be re-enabled on
  `.tapDisabledByTimeout`/`.tapDisabledByUserInput`, and a keyDown swallowed while
  the overlay is active must also swallow its keyUp.
- **Swift 5 language mode** is pinned in `Package.swift` because the C event-tap
  callback touches shared state; bumping to Swift 6 won't compile without reworking it.
- **Names:** the display name has a space (`Mouse Hater`); the executable, bundle,
  and SwiftPM target don't (`MouseHater`) — don't unify them or the build breaks.
- **Signing/Accessibility:** a stable signing identity lives in untracked
  `.signing.local`; an ad-hoc build, or changing the bundle id, means re-granting
  Accessibility.
