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
        #expect(preferenceManager.requestedValues == [false])
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
        let moviesURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies", isDirectory: true)

        #expect(settings.outputDirectoryURL == moviesURL)
        #expect(settings.isUsingDefaultOutputDirectory)
    }

    private final class RecordingDefaultDVDAppPreferenceManager: DefaultDVDAppPreferenceManaging, @unchecked Sendable {
        var isEnabled: Bool
        private(set) var requestedValues: [Bool] = []

        init(isEnabled: Bool) {
            self.isEnabled = isEnabled
        }

        func isSwiftRipDefaultDVDApp() -> Bool {
            isEnabled
        }

        func setSwiftRipAsDefaultDVDApp(_ isEnabled: Bool) throws {
            requestedValues.append(isEnabled)
            self.isEnabled = isEnabled
        }
    }
}
