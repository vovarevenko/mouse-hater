// Copyright © 2026 Vova Revenko

import AppKit
import MouseHaterCore

/// A key the overlay understands once it is active. Letter/symbol keys are
/// delivered as raw keycodes; the controller interprets them per stage.
enum OverlayKey {
    case keyCode(Int64)
    case space
    case escape
}

/// The selection phases of a click.
private enum Stage {
    case column   // step 1: pick a column (a…;, 10 across)
    case row      // step 2: pick a row (q…/, 30 down)
    case refine   // step 3: pick a 10×3 sub-cell (tap = click, hold = nudge)
    case nudge    // holding a refine key: free-move a cursor dot, click on release
}

/// Owns the overlay window and the selection state machine.
///
/// Selection narrows a rectangle, kept in **global display coordinates**
/// (top-left origin, points) so the final point goes straight to `Clicker`.
/// Only the rectangle handed to the view is translated into view-local space.
final class OverlayController {
    /// 10×3 layout for the refine grid, drawn row by row.
    static let refineLayout = ["qwertyuiop", "asdfghjkl;", "zxcvbnm,./"]
    static let columns = 10  // columns in the column step and the refine grid
    static let gridRows = 3  // rows in the refine grid

    /// Column-step labels (home row, left → right).
    static let columnLabels = Array("asdfghjkl;").map(String.init)
    /// Row-step labels (all keys, top → bottom).
    static let rowLabels = Array(refineLayout[0] + refineLayout[1] + refineLayout[2]).map(String.init)
    /// Rows in the row step — always equal to `rowLabels.count`.
    static var verticalRows: Int { rowLabels.count }

    private(set) var active = false
    var onDeactivate: (() -> Void)?

    private var window: NSWindow?
    private var view: OverlayView?

    private var stage: Stage = .column
    private var region: CGRect = .zero        // current selection (global, top-left)
    private var displayBounds: CGRect = .zero // the active display (global, top-left)

    // Nudge state (active only while a refine key is held).
    private var cursorPoint: CGPoint = .zero  // the dot's position (global, top-left)
    private var heldKeyCode: Int64 = -1       // the refine key being held
    private var nudgeRightClick = false       // captured from Shift at hold-start
    private var nudgeVectors: [Int64: CGPoint] = [:]
    private var heldNudgeKeys: Set<Int64> = []  // direction keys currently down
    private var nudgeTimer: Timer?
    private var nudgeHoldTicks = 0
    private var nudgeTicks = 0                   // ticks since the key went down
    private var nudgeRevealed = false           // is the dot shown yet?
    private let nudgeRevealTicks = 8            // ~0.13s before the dot appears (so a plain click doesn't flash it)
    private let nudgeStep: CGFloat = 2           // points for a single tap
    private let nudgeGlideMin: CGFloat = 1       // glide start speed (pt/tick, ~60 pt/s)
    private let nudgeGlideMax: CGFloat = 6       // glide top speed (pt/tick, ~360 pt/s)
    private let nudgeDelayTicks = 12             // ~0.2s held before the glide starts
    private let nudgeRampTicks: CGFloat = 48     // ~0.8s of glide to reach top speed

    // MARK: - Key maps

    private static let keyCodeRows: [[Int64]] = [
        [12, 13, 14, 15, 17, 16, 32, 34, 31, 35], // q w e r t y u i o p
        [0, 1, 2, 3, 5, 4, 38, 40, 37, 41],        // a s d f g h j k l ;
        [6, 7, 8, 9, 11, 45, 46, 43, 47, 44],      // z x c v b n m , . /
    ]

    /// Keycode → 0..<30 in reading order (q,w,…,/). Used by the row step and
    /// the refine grid.
    private static let cellByKeyCode: [Int64: Int] = {
        var map: [Int64: Int] = [:]
        for (r, row) in keyCodeRows.enumerated() {
            for (c, code) in row.enumerated() { map[code] = r * columns + c }
        }
        return map
    }()

    /// Keycode → 0..<10 home row (a…;). Used by the column step.
    private static let columnByKeyCode: [Int64: Int] = {
        var map: [Int64: Int] = [:]
        for (i, code) in keyCodeRows[1].enumerated() { map[code] = i }
        return map
    }()

    // Nudge direction vectors (top-left origin: up = −y). Used while a refine
    // key is held: the hand NOT holding the key nudges the dot.
    // I J K L — right hand — used when the held key is on the LEFT half.
    private static let ijklVectors: [Int64: CGPoint] = [
        34: CGPoint(x: 0, y: -1), // i — up
        40: CGPoint(x: 0, y: 1),  // k — down
        38: CGPoint(x: -1, y: 0), // j — left
        37: CGPoint(x: 1, y: 0),  // l — right
    ]
    // E S D F — left hand (home position) — used when the held key is on the
    // RIGHT half.
    private static let esdfVectors: [Int64: CGPoint] = [
        14: CGPoint(x: 0, y: -1), // e — up
        2: CGPoint(x: 0, y: 1),   // d — down
        1: CGPoint(x: -1, y: 0),  // s — left
        3: CGPoint(x: 1, y: 0),   // f — right
    ]

    // MARK: - Lifecycle

    func toggle() {
        if active { dismiss() } else { open() }
    }

    private func open() {
        guard !active else { return }

        let mouse = NSEvent.mouseLocation // AppKit global coords (bottom-left)
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return }

        let displayID = CGDirectDisplayID(number.uint32Value)
        displayBounds = CGDisplayBounds(displayID)
        region = displayBounds
        stage = .column

        let window = NSWindow(contentRect: screen.frame,
                              styleMask: .borderless,
                              backing: .buffered,
                              defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let view = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window.contentView = view
        window.orderFrontRegardless()

        self.window = window
        self.view = view
        active = true
        refreshView()
    }

    func dismiss() {
        guard active else { return }
        active = false
        window?.orderOut(nil)
        window = nil
        view = nil
        stage = .column
        region = .zero
        heldKeyCode = -1
        nudgeVectors = [:]
        heldNudgeKeys = []
        nudgeHoldTicks = 0
        nudgeTicks = 0
        nudgeRevealed = false
        stopNudgeTimer()
        onDeactivate?()
    }

    // MARK: - Input

    @discardableResult
    func handleKey(_ key: OverlayKey, shift: Bool) -> Bool {
        guard active else { return false }

        switch key {
        case .escape:
            dismiss()

        case .space:
            // Start (nothing picked) → the live cursor; nudge → the steered dot;
            // otherwise → the centre of what's been narrowed so far.
            let target: CGPoint
            switch stage {
            case .column: target = CGEvent(source: nil)?.location ?? GridGeometry.center(of: region)
            case .nudge:  target = cursorPoint
            default:      target = GridGeometry.center(of: region)
            }
            performClick(at: target, shift: shift)

        case .keyCode(let keycode):
            handleKeyCode(keycode, shift: shift)
        }
        return true
    }

    private func handleKeyCode(_ keycode: Int64, shift: Bool) {
        switch stage {
        case .column:
            if let col = Self.columnByKeyCode[keycode] {
                region = GridGeometry.columnRegion(in: region,
                                                   index: col,
                                                   count: Self.columns)
                stage = .row
                refreshView()
            }
        case .row:
            if let row = Self.cellByKeyCode[keycode] {
                region = GridGeometry.rowRegion(in: region,
                                                index: row,
                                                count: Self.verticalRows)
                stage = .refine
                refreshView()
            }
        case .refine:
            // Don't click yet — hold the key to enter nudge; release commits.
            if let index = Self.cellByKeyCode[keycode] {
                enterNudge(cellIndex: index, heldKey: keycode, rightClick: shift)
            }
        case .nudge:
            // A fresh press of a free-hand key reveals the dot (if not already)
            // and makes one discrete step; holding glides (see nudgeTick).
            // Auto-repeat and the held refine key itself are ignored here.
            if let vector = nudgeVectors[keycode], heldNudgeKeys.insert(keycode).inserted {
                revealNudge()
                moveCursor(by: vector, step: nudgeStep)
            }
        }
    }

    /// Called on key release while the overlay is open.
    func handleKeyUp(_ keycode: Int64) {
        guard active, stage == .nudge else { return }
        if keycode == heldKeyCode {
            performClick(at: cursorPoint, shift: nudgeRightClick) // release commits
        } else {
            heldNudgeKeys.remove(keycode)
            if heldNudgeKeys.isEmpty { nudgeHoldTicks = 0 }
        }
    }

    private func enterNudge(cellIndex: Int, heldKey: Int64, rightClick: Bool) {
        let cell = GridGeometry.gridCell(in: region,
                                         index: cellIndex,
                                         columns: Self.columns,
                                         rows: Self.gridRows)
        cursorPoint = GridGeometry.center(of: cell)
        heldKeyCode = heldKey
        nudgeRightClick = rightClick
        heldNudgeKeys = []
        nudgeHoldTicks = 0
        nudgeTicks = 0
        nudgeRevealed = false // hidden until a short hold or a nudge key — a plain click won't flash it
        // A key on the left half is held by the left hand → nudge with the right
        // hand (IJKL); a right-half key → nudge with the left hand (ESDF).
        let leftHalf = (cellIndex % Self.columns) < Self.columns / 2
        nudgeVectors = leftHalf ? Self.ijklVectors : Self.esdfVectors
        stage = .nudge
        startNudgeTimer()
        refreshView() // keeps the 10×3 grid until the dot is revealed
    }

    private func revealNudge() {
        guard !nudgeRevealed else { return }
        nudgeRevealed = true
        refreshView()
    }

    // MARK: - Nudge movement

    /// Drives continuous (and diagonal) gliding while keys are held. Discrete
    /// taps are handled directly in `handleKeyCode`; the timer adds glide after
    /// a short hold, summing every held key's vector (so two keys → diagonal).
    private func startNudgeTimer() {
        stopNudgeTimer()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.nudgeTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        nudgeTimer = timer
    }

    private func stopNudgeTimer() {
        nudgeTimer?.invalidate()
        nudgeTimer = nil
    }

    private func nudgeTick() {
        guard active, stage == .nudge else { return }
        nudgeTicks += 1
        if !nudgeRevealed, nudgeTicks >= nudgeRevealTicks { revealNudge() }

        if heldNudgeKeys.isEmpty { nudgeHoldTicks = 0; return }
        nudgeHoldTicks += 1
        guard nudgeHoldTicks > nudgeDelayTicks else { return }
        var vector = CGPoint.zero
        for key in heldNudgeKeys {
            if let d = nudgeVectors[key] { vector.x += d.x; vector.y += d.y }
        }
        guard vector != .zero else { return }
        // Soft ease-in: start slow (precise) and ramp up the longer it's held.
        let progress = min(1, CGFloat(nudgeHoldTicks - nudgeDelayTicks) / nudgeRampTicks)
        let speed = nudgeGlideMin + (nudgeGlideMax - nudgeGlideMin) * progress * progress
        moveCursor(by: vector, step: speed)
    }

    private func moveCursor(by vector: CGPoint, step: CGFloat) {
        let length = (vector.x * vector.x + vector.y * vector.y).squareRoot()
        guard length > 0 else { return }
        // Normalise so a diagonal moves at the same speed as a cardinal.
        let dx = vector.x / length * step
        let dy = vector.y / length * step
        // Clamp to the active display so the dot stays on screen (maxX/maxY are
        // the first coordinate *past* the display, so step back one point).
        cursorPoint.x = min(max(cursorPoint.x + dx, displayBounds.minX), displayBounds.maxX - 1)
        cursorPoint.y = min(max(cursorPoint.y + dy, displayBounds.minY), displayBounds.maxY - 1)
        refreshView()
    }

    private func performClick(at point: CGPoint, shift: Bool) {
        dismiss() // tear down first so the click lands on the app beneath
        Clicker.click(at: point, type: shift ? .right : .left)
    }

    private func refreshView() {
        if stage == .nudge, nudgeRevealed {
            // The dot is drawn over the live screen (no dimming) for aiming.
            view?.mode = .nudge(CGPoint(x: cursorPoint.x - displayBounds.minX,
                                        y: cursorPoint.y - displayBounds.minY))
            view?.needsDisplay = true
            return
        }

        let local = CGRect(x: region.minX - displayBounds.minX,
                           y: region.minY - displayBounds.minY,
                           width: region.width,
                           height: region.height)
        let mode: OverlayMode
        switch stage {
        case .column:         mode = .cells(Self.columnLabels, Self.rowLabels)
        case .row:            mode = .rows(Self.rowLabels)
        case .refine, .nudge: mode = .grid(Self.refineLayout) // .nudge here only before the dot is revealed
        }
        view?.region = local
        view?.mode = mode
        view?.needsDisplay = true
    }
}
