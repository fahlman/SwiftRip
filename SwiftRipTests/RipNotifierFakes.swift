//
//  RipNotifierFakes.swift
//  SwiftRipTests
//

import Foundation
@testable import SwiftRip

extension RipTestSupport {
    struct NoOpRipNotifier: RipNotifying {
        func notifyRipCompleted(
            outputURL: URL,
            sound: CompletionSound,
            isNotificationEnabled: Bool,
            logError: @escaping @MainActor @Sendable (String) -> Void
        ) {}

        func notifyRipFailed(
            outputURL: URL,
            exitCode: Int32,
            isNotificationEnabled: Bool,
            logError: @escaping @MainActor @Sendable (String) -> Void
        ) {}

        func notifyRipFailed(
            outputURL: URL,
            message: String,
            isNotificationEnabled: Bool,
            logError: @escaping @MainActor @Sendable (String) -> Void
        ) {}
    }

    @MainActor
    final class RecordingRipNotifier: RipNotifying {
        private(set) var completedOutputURLs: [URL] = []
        private(set) var completionSounds: [CompletionSound] = []
        private(set) var notificationEnabledValues: [Bool] = []
        private(set) var failedOutputURLs: [URL] = []
        private(set) var failureExitCodes: [Int32] = []
        private(set) var failureMessages: [String] = []
        private(set) var failureNotificationEnabledValues: [Bool] = []

        func notifyRipCompleted(
            outputURL: URL,
            sound: CompletionSound,
            isNotificationEnabled: Bool,
            logError: @escaping @MainActor @Sendable (String) -> Void
        ) {
            completedOutputURLs.append(outputURL)
            completionSounds.append(sound)
            notificationEnabledValues.append(isNotificationEnabled)
        }

        func notifyRipFailed(
            outputURL: URL,
            exitCode: Int32,
            isNotificationEnabled: Bool,
            logError: @escaping @MainActor @Sendable (String) -> Void
        ) {
            failedOutputURLs.append(outputURL)
            failureExitCodes.append(exitCode)
            failureNotificationEnabledValues.append(isNotificationEnabled)
        }

        func notifyRipFailed(
            outputURL: URL,
            message: String,
            isNotificationEnabled: Bool,
            logError: @escaping @MainActor @Sendable (String) -> Void
        ) {
            failedOutputURLs.append(outputURL)
            failureMessages.append(message)
            failureNotificationEnabledValues.append(isNotificationEnabled)
        }
    }
}
