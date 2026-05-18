//
//  AppStringsTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

struct AppStringsTests {

    @Test func formatsCoreStatusMessages() {
        #expect(AppStrings.initialStatusMessage == "Choose a DVD and output file to begin.")
        #expect(AppStrings.readyToRip("Movie") == "Ready to rip Movie.")
        #expect(AppStrings.ripping("Movie") == "Ripping Movie...")
        #expect(AppStrings.ripStopped == "Rip stopped.")
        #expect(AppStrings.ripMenuTitle == "Rip")
        #expect(AppStrings.revealOutputTitle == "Reveal Output in Finder")
        #expect(AppStrings.revealLogTitle == "Reveal Log in Finder")
    }

    @Test func formatsCompletionAndFailureMessages() {
        #expect(AppStrings.ripFailedNotificationTitle == "Rip Failed")
        #expect(AppStrings.ripFailedNotificationBody(fileName: "Movie.m4v", exitCode: 4) == "Movie.m4v failed with exit code 4.")
        #expect(AppStrings.done(outputPath: "/tmp/Movie.m4v", logPath: "/tmp/Movie.log") == "Done. Saved to /tmp/Movie.m4v. Log saved to /tmp/Movie.log.")
        #expect(AppStrings.handBrakeFailed(exitCode: 4, logPath: "/tmp/Movie.log") == "HandBrakeCLI failed with exit code 4. Log saved to /tmp/Movie.log.")
    }

    @Test func formatsAboutMessages() {
        #expect(AppStrings.aboutTitle(appName: "SwiftRip") == "About SwiftRip")
        #expect(AppStrings.version("1.0", build: "1") == "Version 1.0 (1)")
        #expect(AppStrings.build("1") == "Build 1")
    }

    @Test func exposesSettingsLabels() {
        #expect(AppStrings.settingsFilesTitle == "Files")
        #expect(AppStrings.settingsOutputLocationTitle == "Output Location:")
        #expect(AppStrings.settingsChangeTitle == "Change…")
        #expect(AppStrings.settingsResetTitle == "Reset")
        #expect(AppStrings.settingsCancelTitle == "Cancel")
        #expect(AppStrings.settingsOKTitle == "OK")
        #expect(AppStrings.settingsCompletionTitle == "Completion")
        #expect(AppStrings.settingsCompletionSoundTitle == "Sound:")
        #expect(AppStrings.settingsNotificationTitle == "Show notification when finished")
        #expect(AppStrings.settingsRevealCompletedFileTitle == "Reveal completed file in Finder")
        #expect(AppStrings.settingsAutoEjectTitle == "Eject DVD after successful rip")
        #expect(AppStrings.settingsFilenameFormatTitle == "Filename Format:")
        #expect(AppStrings.completionSoundNoneTitle == "None")
        #expect(AppStrings.filenameFormatDatedTitleCaseTitle == "Movie Name - YYYY-MM-DD.m4v")
    }
}

@MainActor
struct AppSettingsTests {

    @Test func defaultsUseCurrentAppBehavior() {
        let settings = RipTestSupport.makeTestAppSettings()

        #expect(settings.completionSound == .glass)
        #expect(settings.isCompletionNotificationEnabled)
        #expect(settings.shouldRevealCompletedFile)
        #expect(!settings.shouldAutoEjectAfterSuccessfulRip)
        #expect(settings.outputFilenameFormat == .titleCase)
        #expect(settings.isUsingDefaultOutputDirectory)
    }

    @Test func persistsCompletionAndFilenamePreferences() throws {
        let suiteName = "AppSettingsTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(userDefaults: userDefaults, fileManager: .default)
        settings.completionSound = .hero
        settings.isCompletionNotificationEnabled = false
        settings.shouldRevealCompletedFile = false
        settings.shouldAutoEjectAfterSuccessfulRip = true
        settings.outputFilenameFormat = .datedTitleCase

        let reloadedSettings = AppSettings(userDefaults: userDefaults, fileManager: .default)
        #expect(reloadedSettings.completionSound == .hero)
        #expect(!reloadedSettings.isCompletionNotificationEnabled)
        #expect(!reloadedSettings.shouldRevealCompletedFile)
        #expect(reloadedSettings.shouldAutoEjectAfterSuccessfulRip)
        #expect(reloadedSettings.outputFilenameFormat == .datedTitleCase)
    }
}
