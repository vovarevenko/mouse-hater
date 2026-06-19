// Copyright © 2026 Vova Revenko

import CoreGraphics

enum ClickType {
    case left
    case right
}

/// Synthesises mouse movement + a click at a point given in *global display
/// coordinates* (top-left origin, points) — the same space `CGDisplayBounds`
/// and `CGEvent.location` use.
enum Clicker {
    static func click(at point: CGPoint, type: ClickType) {
        let source = CGEventSource(stateID: .hidSystemState)

        // Move the hardware cursor so the click is visibly where we aimed, and
        // re-associate so a subsequent physical mouse move isn't swallowed.
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(1)

        // A move event first — some UIs only reveal click targets on hover.
        post(source, .mouseMoved, point, .left)

        let down: CGEventType
        let up: CGEventType
        let button: CGMouseButton
        switch type {
        case .left:
            down = .leftMouseDown; up = .leftMouseUp; button = .left
        case .right:
            down = .rightMouseDown; up = .rightMouseUp; button = .right
        }

        post(source, down, point, button)
        post(source, up, point, button)
    }

    private static func post(_ source: CGEventSource?,
                             _ type: CGEventType,
                             _ point: CGPoint,
                             _ button: CGMouseButton) {
        guard let event = CGEvent(mouseEventSource: source,
                                  mouseType: type,
                                  mouseCursorPosition: point,
                                  mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.post(tap: .cghidEventTap)
    }
}
