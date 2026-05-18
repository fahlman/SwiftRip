//
//  RipCompletionNotifier.swift
//  SwiftRip
//

import AppKit
import Foundation
import UserNotifications

protocol RipNotifying: Sendable {
    @MainActor
    func notifyRipCompleted(
        outputURL: URL,
        sound: CompletionSound,
        isNotificationEnabled: Bool,
        logError: @escaping @MainActor @Sendable (String) -> Void
    )

    @MainActor
    func notifyRipFailed(
        outputURL: URL,
        exitCode: Int32,
        isNotificationEnabled: Bool,
        logError: @escaping @MainActor @Sendable (String) -> Void
    )
}

struct SystemRipNotifier: RipNotifying {
    @MainActor
    func notifyRipCompleted(
        outputURL: URL,
        sound: CompletionSound,
        isNotificationEnabled: Bool,
        logError: @escaping @MainActor @Sendable (String) -> Void
    ) {
        if let soundName = sound.soundName {
            NSSound(named: soundName)?.play()
        }

        guard isNotificationEnabled else { return }

        showNotification(
            title: AppStrings.ripCompleteNotificationTitle,
            body: AppStrings.ripCompleteNotificationBody(fileName: outputURL.lastPathComponent),
            errorPrefix: "Could not show completion notification",
            logError: logError
        )
    }

    @MainActor
    func notifyRipFailed(
        outputURL: URL,
        exitCode: Int32,
        isNotificationEnabled: Bool,
        logError: @escaping @MainActor @Sendable (String) -> Void
    ) {
        guard isNotificationEnabled else { return }

        showNotification(
            title: AppStrings.ripFailedNotificationTitle,
            body: AppStrings.ripFailedNotificationBody(fileName: outputURL.lastPathComponent, exitCode: exitCode),
            errorPrefix: "Could not show failure notification",
            logError: logError
        )
    }

    @MainActor
    private func showNotification(
        title: String,
        body: String,
        errorPrefix: String,
        logError: @escaping @MainActor @Sendable (String) -> Void
    ) {
        Task {
            let center = UNUserNotificationCenter.current()

            do {
                let isAllowed = try await center.requestAuthorization(options: [.alert, .sound])
                guard isAllowed else { return }

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )

                try await center.add(request)
            } catch {
                logError("\(errorPrefix): \(error.localizedDescription)")
            }
        }
    }
}
