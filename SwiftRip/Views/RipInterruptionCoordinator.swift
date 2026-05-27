//
//  RipInterruptionCoordinator.swift
//  SwiftRip
//

import AppKit
import Observation
import SwiftUI

enum RipInterruptionRequest {
    case windowClose
    case appQuit
}

@MainActor
@Observable
final class RipInterruptionCoordinator {
    static let shared = RipInterruptionCoordinator()

    var isRipActive = false
    private(set) var pendingRequest: RipInterruptionRequest?
    private(set) var shouldAllowConfirmedAppQuit = false
    private(set) var shouldAllowConfirmedWindowClose = false

    @ObservationIgnored
    weak var pendingWindow: NSWindow?

    var hasPendingRequest: Bool {
        pendingRequest != nil
    }

    var shouldConfirmAppQuit: Bool {
        isRipActive && !shouldAllowConfirmedAppQuit
    }

    func updateRipActivity(_ isRipActive: Bool) {
        self.isRipActive = isRipActive

        if !isRipActive {
            clearPendingRequest()
        }
    }

    func shouldConfirmWindowClose(_ window: NSWindow) -> Bool {
        guard isRipActive, !shouldAllowConfirmedWindowClose else { return false }

        pendingWindow = window
        pendingRequest = .windowClose
        return true
    }

    func requestAppQuitConfirmation() {
        pendingRequest = .appQuit
    }

    func clearPendingRequest() {
        pendingRequest = nil
        pendingWindow = nil
        shouldAllowConfirmedAppQuit = false
        shouldAllowConfirmedWindowClose = false
    }

    func closePendingWindowAfterConfirmation() {
        shouldAllowConfirmedWindowClose = true
        let window = pendingWindow
        pendingRequest = nil
        pendingWindow = nil
        window?.performClose(nil)
        shouldAllowConfirmedWindowClose = false
    }

    func quitAppAfterConfirmation() {
        pendingRequest = nil
        pendingWindow = nil
        shouldAllowConfirmedAppQuit = true
        NSApp.terminate(nil)
    }
}

struct WindowCloseConfirmationGate: NSViewRepresentable {

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window, window.delegate !== context.coordinator else { return }
            context.coordinator.previousDelegate = window.delegate
            window.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        weak var previousDelegate: NSWindowDelegate?

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if RipInterruptionCoordinator.shared.shouldConfirmWindowClose(sender) {
                return false
            }

            return previousDelegate?.windowShouldClose?(sender) ?? true
        }
    }
}
