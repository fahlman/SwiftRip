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

    @MainActor
    static func showUsageNotice() -> Bool {
        let alert = NSAlert()
        alert.messageText = AppStrings.usageNoticeTitle
        alert.informativeText = AppStrings.usageNoticeMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: AppStrings.usageNoticeAcknowledgeTitle)
        alert.addButton(withTitle: AppStrings.quitTitle)

        return alert.runModal() == .alertFirstButtonReturn
    }
}
