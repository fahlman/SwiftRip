//
//  RipCompletionNotifier.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/18/26.
//

import AppKit
import Foundation
import UserNotifications

protocol RipCompletionNotifying {
    @MainActor
    func notifyRipCompleted(
        outputURL: URL,
        logError: @escaping @MainActor (String) -> Void
    )
}

struct SystemRipCompletionNotifier: RipCompletionNotifying {
    @MainActor
    func notifyRipCompleted(
        outputURL: URL,
        logError: @escaping @MainActor (String) -> Void
    ) {
        NSSound(named: "Glass")?.play()

        Task {
            let center = UNUserNotificationCenter.current()

            do {
                let isAllowed = try await center.requestAuthorization(options: [.alert, .sound])
                guard isAllowed else { return }

                let content = UNMutableNotificationContent()
                content.title = AppStrings.ripCompleteNotificationTitle
                content.body = AppStrings.ripCompleteNotificationBody(fileName: outputURL.lastPathComponent)
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )

                try await center.add(request)
            } catch {
                logError("Could not show completion notification: \(error.localizedDescription)")
            }
        }
    }
}
