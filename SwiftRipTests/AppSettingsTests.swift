//
//  AppSettingsTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct AppSettingsTests {

    @Test func defaultsUseCurrentAppBehavior() {
        let settings = RipTestSupport.makeTestAppSettings()

        #expect(settings.completionSound == .glass)
        #expect(settings.isCompletionNotificationEnabled)
        #expect(settings.shouldRevealCompletedFile)
        #expect(!settings.shouldAutoEjectAfterSuccessfulRip)
        #expect(settings.outputFilenameFormat == .titleCase)
        #expect(!settings.isDefaultDVDAppOnInsertEnabled)
        #expect(settings.isUsingDefaultOutputDirectory)
        #expect(settings.needsOutputDirectoryPermission)
    }

    @Test func persistsCompletionAndFilenamePreferences() throws {
        let suiteName = "AppSettingsTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(
            userDefaults: userDefaults,
            fileManager: .default,
            defaultDVDAppPreferenceManager: RipTestSupport.StubDefaultDVDAppPreferenceManager()
        )
        settings.completionSound = .hero
        settings.isCompletionNotificationEnabled = false
        settings.shouldRevealCompletedFile = false
        settings.shouldAutoEjectAfterSuccessfulRip = true
        settings.outputFilenameFormat = .datedTitleCase

        let reloadedSettings = AppSettings(
            userDefaults: userDefaults,
            fileManager: .default,
            defaultDVDAppPreferenceManager: RipTestSupport.StubDefaultDVDAppPreferenceManager()
        )
        #expect(reloadedSettings.completionSound == .hero)
        #expect(!reloadedSettings.isCompletionNotificationEnabled)
        #expect(!reloadedSettings.shouldRevealCompletedFile)
        #expect(reloadedSettings.shouldAutoEjectAfterSuccessfulRip)
        #expect(reloadedSettings.outputFilenameFormat == .datedTitleCase)
    }

    @Test func invalidPersistedEnumValuesFallBackToDefaults() throws {
        let suiteName = "AppSettingsTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        userDefaults.set("invalid-sound", forKey: "completionSound")
        userDefaults.set("invalid-format", forKey: "outputFilenameFormat")

        let settings = AppSettings(
            userDefaults: userDefaults,
            fileManager: .default,
            defaultDVDAppPreferenceManager: RipTestSupport.StubDefaultDVDAppPreferenceManager()
        )
        #expect(settings.completionSound == .glass)
        #expect(settings.outputFilenameFormat == .titleCase)
    }

    @Test func defaultDVDAppPreferenceReflectsSystemPreferenceManager() throws {
        let suiteName = "AppSettingsTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let preferenceManager = RecordingDefaultDVDAppPreferenceManager(isEnabled: true)

        let settings = AppSettings(
            userDefaults: userDefaults,
            fileManager: .default,
            defaultDVDAppPreferenceManager: preferenceManager
        )

        #expect(settings.isDefaultDVDAppOnInsertEnabled)

        try settings.setDefaultDVDAppOnInsertEnabled(false)

        #expect(!settings.isDefaultDVDAppOnInsertEnabled)
        #expect(preferenceManager.restoredActions == [nil])
    }

    @Test func defaultDVDAppPreferenceRestoresPreviousActionWhenDisabled() throws {
        let suiteName = "AppSettingsTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let previousAction = DigitalHubDVDAction(action: 105)
        let preferenceManager = RecordingDefaultDVDAppPreferenceManager(
            isEnabled: false,
            currentAction: previousAction
        )
        let settings = AppSettings(
            userDefaults: userDefaults,
            fileManager: .default,
            defaultDVDAppPreferenceManager: preferenceManager
        )

        try settings.setDefaultDVDAppOnInsertEnabled(true)
        #expect(settings.isDefaultDVDAppOnInsertEnabled)

        try settings.setDefaultDVDAppOnInsertEnabled(false)

        #expect(!settings.isDefaultDVDAppOnInsertEnabled)
        #expect(preferenceManager.makeDefaultCallCount == 1)
        #expect(preferenceManager.restoredActions == [previousAction])
    }

    @Test func disablingDefaultDVDAppDoesNotOverwriteIfSwiftRipNoLongerOwnsTheHandler() throws {
        let suiteName = "AppSettingsTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let preferenceManager = RecordingDefaultDVDAppPreferenceManager(
            isEnabled: false,
            currentAction: DigitalHubDVDAction(action: 105)
        )
        let settings = AppSettings(
            userDefaults: userDefaults,
            fileManager: .default,
            defaultDVDAppPreferenceManager: preferenceManager
        )

        try settings.setDefaultDVDAppOnInsertEnabled(false)

        #expect(preferenceManager.restoredActions.isEmpty)
    }

    @Test func invalidOutputDirectoryBookmarkFallsBackToMovies() throws {
        let suiteName = "AppSettingsTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        userDefaults.set(Data("invalid bookmark data".utf8), forKey: "outputDirectoryBookmark")

        let settings = AppSettings(
            userDefaults: userDefaults,
            fileManager: .default,
            defaultDVDAppPreferenceManager: RipTestSupport.StubDefaultDVDAppPreferenceManager()
        )
        let moviesURL = AppSettings.defaultMoviesDirectory(using: .default)

        #expect(settings.outputDirectoryURL == moviesURL)
        #expect(settings.isUsingDefaultOutputDirectory)
        #expect(settings.needsOutputDirectoryPermission)
    }

    private final class RecordingDefaultDVDAppPreferenceManager: DefaultDVDAppPreferenceManaging, @unchecked Sendable {
        var isEnabled: Bool
        var currentAction: DigitalHubDVDAction?
        private(set) var makeDefaultCallCount = 0
        private(set) var restoredActions: [DigitalHubDVDAction?] = []

        init(isEnabled: Bool, currentAction: DigitalHubDVDAction? = nil) {
            self.isEnabled = isEnabled
            self.currentAction = currentAction
        }

        func isSwiftRipDefaultDVDApp() -> Bool {
            isEnabled
        }

        func currentDVDAction() -> DigitalHubDVDAction? {
            currentAction
        }

        func makeSwiftRipDefaultDVDApp() throws {
            makeDefaultCallCount += 1
            isEnabled = true
        }

        func restoreDVDAction(_ action: DigitalHubDVDAction?) throws {
            restoredActions.append(action)
            currentAction = action
            isEnabled = false
        }
    }
}
