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
        #expect(!settings.hasAcknowledgedCurrentUsageNotice)
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
            fileManager: .default
        )
        settings.completionSound = .hero
        settings.isCompletionNotificationEnabled = false
        settings.shouldRevealCompletedFile = false
        settings.shouldAutoEjectAfterSuccessfulRip = true
        settings.outputFilenameFormat = .datedTitleCase

        let reloadedSettings = AppSettings(
            userDefaults: userDefaults,
            fileManager: .default
        )
        #expect(reloadedSettings.completionSound == .hero)
        #expect(!reloadedSettings.isCompletionNotificationEnabled)
        #expect(!reloadedSettings.shouldRevealCompletedFile)
        #expect(reloadedSettings.shouldAutoEjectAfterSuccessfulRip)
        #expect(reloadedSettings.outputFilenameFormat == .datedTitleCase)
    }

    @Test func persistsUsageNoticeAcknowledgement() throws {
        let suiteName = "AppSettingsTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(
            userDefaults: userDefaults,
            fileManager: .default
        )

        #expect(!settings.hasAcknowledgedCurrentUsageNotice)
        settings.acknowledgeCurrentUsageNotice()
        #expect(settings.hasAcknowledgedCurrentUsageNotice)

        let reloadedSettings = AppSettings(
            userDefaults: userDefaults,
            fileManager: .default
        )
        #expect(reloadedSettings.hasAcknowledgedCurrentUsageNotice)
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
            fileManager: .default
        )
        #expect(settings.completionSound == .glass)
        #expect(settings.outputFilenameFormat == .titleCase)
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
            fileManager: .default
        )
        let moviesURL = AppSettings.defaultMoviesDirectory(using: .default)

        #expect(settings.outputDirectoryURL == moviesURL)
        #expect(settings.isUsingDefaultOutputDirectory)
        #expect(settings.needsOutputDirectoryPermission)
    }

}
