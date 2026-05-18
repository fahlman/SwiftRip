//
//  AppStrings.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/17/26.
//

import Foundation

enum AppStrings {
    static let chooseDVDTitle = localized("Choose DVD…")
    static let ripTitle = localized("Rip")
    static let stopTitle = localized("Stop")
    static let ejectTitle = localized("Eject")
    static let noValidDVDTitle = localized("No valid DVD")
    static let ripCompleteNotificationTitle = localized("Rip Complete")
    static let initialStatusMessage = localized("Choose a DVD and output file to begin.")
    static let fallbackMovieName = localized("Movie")
    static let readyStatusPrefix = localized("Ready to rip ")
    static let aboutDescription = localized("A small macOS DVD ripping tool built around bundled ARM64 ripping tools.")
    static let bundledToolsTitle = localized("Bundled Tools")
    static let licensesTitle = localized("Licenses")
    static let showLicensesTitle = localized("Show Licenses")
    static let noLicensesFound = localized("No bundled license files were found.")
    static let versionUnknown = localized("Version unknown")

    static func aboutTitle(appName: String) -> String {
        String(format: localized("About %@"), appName)
    }

    static func licenseDescription(appName: String) -> String {
        String(
            format: localized("%@ includes bundled third-party tools. Their license files are included in the app bundle resources."),
            appName
        )
    }

    static func version(_ version: String) -> String {
        String(format: localized("Version %@"), version)
    }

    static func version(_ version: String, build: String) -> String {
        String(format: localized("Version %@ (%@)"), version, build)
    }

    static func build(_ build: String) -> String {
        String(format: localized("Build %@"), build)
    }

    static func chooseVideoTSFolder(directoryName: String) -> String {
        String(format: localized("Choose a folder that contains a %@ directory."), directoryName)
    }

    static func readyToRip(_ dvdName: String) -> String {
        String(format: localized("Ready to rip %@."), dvdName)
    }

    static func ripping(_ dvdName: String) -> String {
        String(format: localized("Ripping %@..."), dvdName)
    }

    static func ripCompleteNotificationBody(fileName: String) -> String {
        String(format: localized("Saved %@"), fileName)
    }

    static let ripStopped = localized("Rip stopped.")

    static func done(outputPath: String, logPath: String) -> String {
        String(format: localized("Done. Saved to %@. Log saved to %@."), outputPath, logPath)
    }

    static func handBrakeFailed(exitCode: Int32, logPath: String) -> String {
        String(format: localized("HandBrakeCLI failed with exit code %d. Log saved to %@."), exitCode, logPath)
    }

    static func missingHandBrakeCLI(path: String) -> String {
        String(format: localized("%@ was not found at %@."), RipConfiguration.handBrakeCLIExecutableName, path)
    }

    static func missingLibdvdcss(path: String) -> String {
        String(format: localized("%@ was not found at %@."), RipConfiguration.libdvdcssLibraryName, path)
    }

    static func missingPreset(appName: String, path: String) -> String {
        String(format: localized("%@ preset was not found at %@."), appName, path)
    }

    static func logSaved(to logPath: String) -> String {
        String(format: localized("Log saved to %@."), logPath)
    }

    static func couldNotWriteLog(_ errorDescription: String) -> String {
        String(format: localized("Could not write log: %@"), errorDescription)
    }

    private static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}
