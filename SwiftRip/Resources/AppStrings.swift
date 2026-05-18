//
//  AppStrings.swift
//  SwiftRip
//

import Foundation

enum AppStrings {
    nonisolated static let chooseDVDTitle = localized("Choose DVD…")
    nonisolated static let ripTitle = localized("Rip")
    nonisolated static let stopTitle = localized("Stop")
    nonisolated static let ejectTitle = localized("Eject")
    nonisolated static let ripMenuTitle = localized("Rip")
    nonisolated static let revealOutputTitle = localized("Reveal Output in Finder")
    nonisolated static let revealLogTitle = localized("Reveal Log in Finder")
    nonisolated static let noValidDVDTitle = localized("No valid DVD")
    nonisolated static let ripCompleteNotificationTitle = localized("Rip Complete")
    nonisolated static let ripFailedNotificationTitle = localized("Rip Failed")
    nonisolated static let stopRipConfirmationTitle = localized("Stop Rip?")
    nonisolated static let stopRipConfirmationMessage = localized("Stopping now will terminate HandBrakeCLI and delete the incomplete output file.")
    nonisolated static let keepRippingTitle = localized("Keep Ripping")
    nonisolated static let dvdStatusAccessibilityLabel = localized("DVD status")
    nonisolated static let progressAccessibilityLabel = localized("Rip progress")
    nonisolated static let initialStatusMessage = localized("Choose a DVD and output file to begin.")
    nonisolated static let fallbackMovieName = localized("Movie")
    nonisolated static let readyStatusPrefix = localized("Ready to rip ")
    nonisolated static let aboutDescription = localized("A small macOS DVD ripping tool built around bundled ARM64 ripping tools.")
    nonisolated static let bundledToolsTitle = localized("Bundled Tools")
    nonisolated static let licensesTitle = localized("Licenses")
    nonisolated static let showLicensesTitle = localized("Show Licenses")
    nonisolated static let noLicensesFound = localized("No bundled license files were found.")
    nonisolated static let versionUnknown = localized("Version unknown")
    nonisolated static let settingsFilesTitle = localized("Files")
    nonisolated static let settingsOutputLocationTitle = localized("Output Location:")
    nonisolated static let settingsChangeTitle = localized("Change…")
    nonisolated static let settingsResetTitle = localized("Reset")
    nonisolated static let settingsCancelTitle = localized("Cancel")
    nonisolated static let settingsOKTitle = localized("OK")
    nonisolated static let settingsChangePrompt = localized("Change")
    nonisolated static let settingsCompletionTitle = localized("Completion")
    nonisolated static let settingsCompletionSoundTitle = localized("Sound:")
    nonisolated static let settingsNotificationTitle = localized("Show notification when finished")
    nonisolated static let settingsRevealCompletedFileTitle = localized("Reveal completed file in Finder")
    nonisolated static let settingsAutoEjectTitle = localized("Eject DVD after successful rip")
    nonisolated static let settingsFilenameFormatTitle = localized("Filename Format:")
    nonisolated static let completionSoundGlassTitle = localized("Glass")
    nonisolated static let completionSoundPingTitle = localized("Ping")
    nonisolated static let completionSoundHeroTitle = localized("Hero")
    nonisolated static let completionSoundNoneTitle = localized("None")
    nonisolated static let filenameFormatTitleCaseTitle = localized("Movie Name.m4v")
    nonisolated static let filenameFormatOriginalNameTitle = localized("MOVIE_NAME.m4v")
    nonisolated static let filenameFormatDatedTitleCaseTitle = localized("Movie Name - YYYY-MM-DD.m4v")

    nonisolated static func aboutTitle(appName: String) -> String {
        String(format: localized("About %@"), appName)
    }

    nonisolated static func licenseDescription(appName: String) -> String {
        String(
            format: localized("%@ includes bundled third-party tools. Their license files are included in the app bundle resources."),
            appName
        )
    }

    nonisolated static func version(_ version: String) -> String {
        String(format: localized("Version %@"), version)
    }

    nonisolated static func version(_ version: String, build: String) -> String {
        String(format: localized("Version %@ (%@)"), version, build)
    }

    nonisolated static func build(_ build: String) -> String {
        String(format: localized("Build %@"), build)
    }

    nonisolated static func chooseVideoTSFolder(directoryName: String) -> String {
        String(format: localized("Choose a folder that contains a %@ directory."), directoryName)
    }

    nonisolated static func readyToRip(_ dvdName: String) -> String {
        String(format: localized("Ready to rip %@."), dvdName)
    }

    nonisolated static func ripping(_ dvdName: String) -> String {
        String(format: localized("Ripping %@..."), dvdName)
    }

    nonisolated static func percentComplete(_ percent: Int) -> String {
        String(format: localized("%d percent"), percent)
    }

    nonisolated static func ripCompleteNotificationBody(fileName: String) -> String {
        String(format: localized("Saved %@"), fileName)
    }

    nonisolated static func ripFailedNotificationBody(fileName: String, exitCode: Int32) -> String {
        String(format: localized("%@ failed with exit code %d."), fileName, exitCode)
    }

    nonisolated static let ripStopped = localized("Rip stopped.")

    nonisolated static func done(outputPath: String, logPath: String) -> String {
        String(format: localized("Done. Saved to %@. Log saved to %@."), outputPath, logPath)
    }

    nonisolated static func handBrakeFailed(exitCode: Int32, logPath: String) -> String {
        String(format: localized("HandBrakeCLI failed with exit code %d. Log saved to %@."), exitCode, logPath)
    }

    nonisolated static func missingHandBrakeCLI(path: String) -> String {
        String(format: localized("%@ was not found at %@."), RipConfiguration.handBrakeCLIExecutableName, path)
    }

    nonisolated static func missingLibdvdcss(path: String) -> String {
        String(format: localized("%@ was not found at %@."), RipConfiguration.libdvdcssLibraryName, path)
    }

    nonisolated static func missingPreset(appName: String, path: String) -> String {
        String(format: localized("%@ preset was not found at %@."), appName, path)
    }

    nonisolated static func logSaved(to logPath: String) -> String {
        String(format: localized("Log saved to %@."), logPath)
    }

    nonisolated static func couldNotWriteLog(_ errorDescription: String) -> String {
        String(format: localized("Could not write log: %@"), errorDescription)
    }

    private nonisolated static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}
