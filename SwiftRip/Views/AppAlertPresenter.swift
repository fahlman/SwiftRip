//
//  AppAlertPresenter.swift
//  SwiftRip
//

import AppKit

enum AppAlertPresenter {
    @MainActor
    static func showWarning(messageText: String, informativeText: String) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = .warning
        alert.runModal()
    }
}
