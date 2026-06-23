// Copyright © 2026 Vova Revenko

import XCTest
@testable import MouseHaterCore

final class CommandTapRecognizerTests: XCTestCase {
    func testSingleCleanTapTriggers() {
        var recognizer = CommandTapRecognizer()

        XCTAssertFalse(recognizer.handle(.flagsChanged(command: true, otherModifiers: false),
                                         at: 10,
                                         mode: .singleTap))
        XCTAssertTrue(recognizer.handle(.flagsChanged(command: false, otherModifiers: false),
                                        at: 10.1,
                                        mode: .singleTap))
    }

    func testLongCommandPressDoesNotTrigger() {
        var recognizer = CommandTapRecognizer()

        _ = recognizer.handle(.flagsChanged(command: true, otherModifiers: false),
                              at: 10,
                              mode: .singleTap)
        XCTAssertFalse(recognizer.handle(.flagsChanged(command: false, otherModifiers: false),
                                         at: 10.31,
                                         mode: .singleTap))
    }

    func testShortcutDoesNotTrigger() {
        var recognizer = CommandTapRecognizer()

        _ = recognizer.handle(.flagsChanged(command: true, otherModifiers: false),
                              at: 10,
                              mode: .singleTap)
        _ = recognizer.handle(.keyDown(isRepeat: false), at: 10.05, mode: .singleTap)
        _ = recognizer.handle(.keyUp, at: 10.1, mode: .singleTap)
        XCTAssertFalse(recognizer.handle(.flagsChanged(command: false, otherModifiers: false),
                                         at: 10.15,
                                         mode: .singleTap))
    }

    func testOtherModifierCancelsCandidate() {
        var recognizer = CommandTapRecognizer()

        _ = recognizer.handle(.flagsChanged(command: true, otherModifiers: false),
                              at: 10,
                              mode: .singleTap)
        _ = recognizer.handle(.flagsChanged(command: true, otherModifiers: true),
                              at: 10.05,
                              mode: .singleTap)
        XCTAssertFalse(recognizer.handle(.flagsChanged(command: false, otherModifiers: false),
                                         at: 10.1,
                                         mode: .singleTap))
    }

    func testDoubleTapTriggersOnSecondTapWithinGap() {
        var recognizer = CommandTapRecognizer()

        XCTAssertFalse(performTap(on: &recognizer, downAt: 10, mode: .doubleTap))
        XCTAssertTrue(performTap(on: &recognizer, downAt: 10.25, mode: .doubleTap))
    }

    func testExpiredDoubleTapStartsANewPair() {
        var recognizer = CommandTapRecognizer()

        XCTAssertFalse(performTap(on: &recognizer, downAt: 10, mode: .doubleTap))
        XCTAssertFalse(performTap(on: &recognizer, downAt: 10.5, mode: .doubleTap))
        XCTAssertTrue(performTap(on: &recognizer, downAt: 10.75, mode: .doubleTap))
    }

    func testAutorepeatDoesNotLeaveAnotherKeyMarkedAsHeld() {
        var recognizer = CommandTapRecognizer()

        _ = recognizer.handle(.keyDown(isRepeat: false), at: 10, mode: .singleTap)
        _ = recognizer.handle(.keyDown(isRepeat: true), at: 10.1, mode: .singleTap)
        _ = recognizer.handle(.keyUp, at: 10.2, mode: .singleTap)

        XCTAssertTrue(performTap(on: &recognizer, downAt: 10.3, mode: .singleTap))
    }

    func testResetClearsPendingDoubleTap() {
        var recognizer = CommandTapRecognizer()

        XCTAssertFalse(performTap(on: &recognizer, downAt: 10, mode: .doubleTap))
        recognizer.reset()
        XCTAssertFalse(performTap(on: &recognizer, downAt: 10.25, mode: .doubleTap))
    }

    private func performTap(on recognizer: inout CommandTapRecognizer,
                            downAt: TimeInterval,
                            mode: TriggerMode) -> Bool {
        _ = recognizer.handle(.flagsChanged(command: true, otherModifiers: false),
                              at: downAt,
                              mode: mode)
        return recognizer.handle(.flagsChanged(command: false, otherModifiers: false),
                                 at: downAt + 0.1,
                                 mode: mode)
    }
}
