// Copyright © 2026 Vova Revenko

import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void

    init(isLoginItemEnabled: @escaping () -> Bool,
         enableLoginItem: @escaping () -> Bool,
         openLoginItemSettings: @escaping () -> Void,
         isAccessibilityTrusted: @escaping () -> Bool,
         requestAccessibility: @escaping () -> Void,
         onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init(window: nil)

        let rootView = OnboardingView(
            isLoginItemEnabled: isLoginItemEnabled,
            enableLoginItem: enableLoginItem,
            openLoginItemSettings: openLoginItemSettings,
            isAccessibilityTrusted: isAccessibilityTrusted,
            requestAccessibility: requestAccessibility,
            finish: { [weak self] in self?.close() })

        let hosting = NSHostingView(rootView: rootView)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "Mouse Hater Setup"
        window.contentView = hosting
        window.center()
        window.delegate = self
        self.window = window
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

@MainActor
private struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case intro
        case loginItem
        case accessibility
    }

    private enum FocusTarget: Hashable {
        case introContinue
        case enableLogin
        case loginContinue
        case requestAccessibility
        case checkAccessibility
        case done
    }

    private let isLoginItemEnabled: () -> Bool
    private let enableLoginItem: () -> Bool
    private let openLoginItemSettings: () -> Void
    private let isAccessibilityTrusted: () -> Bool
    private let requestAccessibility: () -> Void
    private let finish: () -> Void

    @State private var step: Step = .intro
    @State private var loginEnabled: Bool
    @State private var loginMessage: String?
    @State private var accessibilityGranted: Bool
    @State private var didRequestAccessibility = false
    @State private var awaitingAccessibilityReturn = false
    @FocusState private var focusedButton: FocusTarget?

    init(isLoginItemEnabled: @escaping () -> Bool,
         enableLoginItem: @escaping () -> Bool,
         openLoginItemSettings: @escaping () -> Void,
         isAccessibilityTrusted: @escaping () -> Bool,
         requestAccessibility: @escaping () -> Void,
         finish: @escaping () -> Void) {
        self.isLoginItemEnabled = isLoginItemEnabled
        self.enableLoginItem = enableLoginItem
        self.openLoginItemSettings = openLoginItemSettings
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.requestAccessibility = requestAccessibility
        self.finish = finish
        _loginEnabled = State(initialValue: isLoginItemEnabled())
        _accessibilityGranted = State(initialValue: isAccessibilityTrusted())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            progress

            switch step {
            case .intro:
                introStep
            case .loginItem:
                loginItemStep
            case .accessibility:
                accessibilityStep
            }
        }
        .padding(28)
        .frame(width: 520, height: 360, alignment: .topLeading)
        .onAppear {
            focusPrimarySoon()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            handleAppBecameActive()
        }
    }

    private var progress: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: item == step ? 36 : 18, height: 5)
            }

            Spacer()
        }
        .accessibilityHidden(true)
    }

    private var introStep: some View {
        StepLayout(
            title: "Click from the keyboard",
            text: "Mouse Hater lets you control mouse clicks from the keyboard when a mouse or trackpad is unavailable, uncomfortable, or simply not the right tool.",
            footer: {
                Button("Continue") {
                    step = .loginItem
                    focusPrimarySoon()
                }
                .focused($focusedButton, equals: .introContinue)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            })
    }

    private var loginItemStep: some View {
        StepLayout(
            title: "Start when you sign in?",
            text: "This is optional. Enable Open at Login if you want Mouse Hater ready in the menu bar after restarting your Mac.",
            footer: {
                VStack(alignment: .leading, spacing: 10) {
                    if let loginMessage {
                        Text(loginMessage)
                            .font(.callout)
                            .foregroundStyle(loginEnabled ? Color.secondary : Color.orange)
                    }

                    HStack {
                        if loginEnabled {
                            Button("Open at Login Enabled") {}
                                .disabled(true)

                            Spacer()

                            Button("Continue") {
                                step = .accessibility
                                focusPrimarySoon()
                            }
                            .focused($focusedButton, equals: .loginContinue)
                            .keyboardShortcut(.defaultAction)
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Enable Open at Login") {
                                enableLogin()
                            }
                            .focused($focusedButton, equals: .enableLogin)
                            .keyboardShortcut(.defaultAction)
                            .buttonStyle(.borderedProminent)

                            Spacer()

                            Button("Not Now") {
                                step = .accessibility
                                focusPrimarySoon()
                            }
                        }
                    }
                }
            })
    }

    private var accessibilityStep: some View {
        StepLayout(
            title: "Allow keyboard control",
            text: "Mouse Hater needs macOS Accessibility permission to listen for your global Command-key trigger and send the click you choose. The permission is used only for keyboard-driven mouse control.",
            footer: {
                VStack(alignment: .leading, spacing: 10) {
                    Text(accessibilityHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack {
                        accessibilityRequestButton

                        checkAccessibilityButton

                        Spacer()

                        if accessibilityGranted {
                            Button("Done") {
                                finish()
                            }
                            .focused($focusedButton, equals: .done)
                            .keyboardShortcut(.defaultAction)
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Finish Setup Later") {
                                finish()
                            }
                        }
                    }
                }
            })
    }

    private func enableLogin() {
        if enableLoginItem() {
            loginEnabled = true
            loginMessage = "Mouse Hater will open automatically when you sign in."
            focusPrimarySoon()
        } else {
            loginEnabled = isLoginItemEnabled()
            loginMessage = "macOS needs you to approve this in Login Items settings."
            openLoginItemSettings()
            focusPrimarySoon()
        }
    }

    private var accessibilityHint: String {
        if accessibilityGranted {
            return "Accessibility is enabled."
        }
        if didRequestAccessibility {
            return "After approving Mouse Hater in System Settings, return here and click Check Again."
        }
        return "You can also enable this later from the menu-bar icon."
    }

    @ViewBuilder
    private var accessibilityRequestButton: some View {
        if accessibilityGranted {
            Button("Accessibility Enabled") {}
                .disabled(true)
        } else if didRequestAccessibility {
            Button("Request Permission") {
                awaitingAccessibilityReturn = true
                requestAccessibility()
                refreshAccessibilityAfterRequestIfAlreadyGranted()
            }
            .buttonStyle(.bordered)
        } else {
            Button("Request Permission") {
                awaitingAccessibilityReturn = true
                requestAccessibility()
                refreshAccessibilityAfterRequestIfAlreadyGranted()
            }
            .focused($focusedButton, equals: .requestAccessibility)
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var checkAccessibilityButton: some View {
        if didRequestAccessibility && !accessibilityGranted {
            Button("Check Again") {
                accessibilityGranted = isAccessibilityTrusted()
                focusPrimarySoon()
            }
            .focused($focusedButton, equals: .checkAccessibility)
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        } else {
            Button("Check Again") {
                accessibilityGranted = isAccessibilityTrusted()
                focusPrimarySoon()
            }
            .disabled(accessibilityGranted)
        }
    }

    private var primaryFocus: FocusTarget {
        switch step {
        case .intro:
            return .introContinue
        case .loginItem:
            return loginEnabled ? .loginContinue : .enableLogin
        case .accessibility:
            if accessibilityGranted {
                return .done
            }
            return didRequestAccessibility ? .checkAccessibility : .requestAccessibility
        }
    }

    private func focusPrimarySoon() {
        DispatchQueue.main.async {
            focusedButton = primaryFocus
        }
    }

    private func handleAppBecameActive() {
        guard awaitingAccessibilityReturn else { return }
        awaitingAccessibilityReturn = false
        didRequestAccessibility = true
        accessibilityGranted = isAccessibilityTrusted()
        focusPrimarySoon()
    }

    private func refreshAccessibilityAfterRequestIfAlreadyGranted() {
        if isAccessibilityTrusted() {
            awaitingAccessibilityReturn = false
            didRequestAccessibility = true
            accessibilityGranted = true
            focusPrimarySoon()
        }
    }
}

@MainActor
private struct StepLayout<Footer: View>: View {
    let title: String
    let text: String
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            footer
        }
    }
}
