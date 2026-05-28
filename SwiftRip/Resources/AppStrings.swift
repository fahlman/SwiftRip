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
    nonisolated static let checkForUpdatesTitle = localized("Check for Updates…")
    nonisolated static let revealOutputTitle = localized("Reveal Output in Finder")
    nonisolated static let revealLogTitle = localized("Reveal Log in Finder")
    nonisolated static let noValidDVDTitle = localized("No valid DVD")
    nonisolated static let invalidDVDSelectionTitle = localized("Not a Video DVD")
    nonisolated static let ripCompleteNotificationTitle = localized("Rip Complete")
    nonisolated static let ripFailedNotificationTitle = localized("Rip Failed")
    nonisolated static let stopRipConfirmationTitle = localized("Stop Rip?")
    nonisolated static let stopRipConfirmationMessage = localized("Stopping now will terminate HandBrakeCLI and delete the incomplete output file.")
    nonisolated static let keepRippingTitle = localized("Keep Ripping")
    nonisolated static let dvdStatusAccessibilityLabel = localized("DVD status")
    nonisolated static let progressAccessibilityLabel = localized("Rip progress")
    nonisolated static let initialStatusMessage = localized("Choose a DVD and output file to begin.")
    nonisolated static let fallbackMovieName = localized("Movie")
    nonisolated static let aboutDescription = localized("A small macOS DVD ripping tool built around bundled ripping tools.")
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
    nonisolated static let chooseOutputFolderPrompt = localized("Choose Output Folder")
    nonisolated static let outputFolderPermissionMessage = localized("SwiftRip needs permission to save ripped movies outside its app container. Choose Movies or another output folder.")
    nonisolated static let outputFolderPermissionFailedTitle = localized("Could Not Use Output Folder")
    nonisolated static let outputDirectoryMissing = localized("The output folder does not exist.")
    nonisolated static let outputDirectoryNotFolder = localized("The output location is not a folder.")
    nonisolated static let firstRunOutputFolderMessage = localized("Choose where SwiftRip should save ripped movies. You can change this later in Settings.")
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
    nonisolated static let ripLogOutcomeCompleted = localized("Completed")
    nonisolated static let ripLogOutcomeFailed = localized("Failed")
    nonisolated static let ripLogOutcomeCanceled = localized("Canceled")
    nonisolated static let ripLogOutcomePreflightFailed = localized("Preflight failed")
    nonisolated static let ripLogFallbackDVDName = localized("DVD")
    nonisolated static let ripLogRipStoppedByUser = localized("Rip stopped by user.")
    nonisolated static let ripNotificationCompletionErrorPrefix = localized("Could not show completion notification")
    nonisolated static let ripNotificationFailureErrorPrefix = localized("Could not show failure notification")

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

    nonisolated static func percentDisplay(_ percent: Int) -> String {
        String(format: localized("%d%%"), percent)
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

    nonisolated static func outputDirectoryNotWritable(_ path: String, errorDescription: String) -> String {
        String(format: localized("SwiftRip cannot write to %@. %@"), path, errorDescription)
    }

    nonisolated static func outputFileMissing(_ path: String) -> String {
        String(format: localized("HandBrakeCLI finished, but no output file was created at %@."), path)
    }

    nonisolated static func outputFileEmpty(_ path: String) -> String {
        String(format: localized("HandBrakeCLI finished, but the output file at %@ is empty."), path)
    }

    nonisolated static func outputFileIsFolder(_ path: String) -> String {
        String(format: localized("HandBrakeCLI finished, but %@ is a folder instead of a movie file."), path)
    }

    nonisolated static func outputFileNotReadable(_ path: String, errorDescription: String) -> String {
        String(format: localized("SwiftRip could not verify the output file at %@. %@"), path, errorDescription)
    }

    nonisolated static func ripLogTitle(appName: String) -> String {
        String(format: localized("%@ Log"), appName)
    }

    nonisolated static func ripLogApp(appName: String, version: String) -> String {
        String(format: localized("App: %@ %@"), appName, version)
    }

    nonisolated static func ripLogStarted(_ startedAt: String) -> String {
        String(format: localized("Started: %@"), startedAt)
    }

    nonisolated static func ripLogDVD(_ dvdName: String) -> String {
        String(format: localized("DVD: %@"), dvdName)
    }

    nonisolated static func ripLogInput(_ path: String) -> String {
        String(format: localized("Input: %@"), path)
    }

    nonisolated static func ripLogOutput(_ path: String) -> String {
        String(format: localized("Output: %@"), path)
    }

    nonisolated static func ripLogHandBrakeCLI(_ path: String) -> String {
        String(format: localized("HandBrakeCLI: %@"), path)
    }

    nonisolated static func ripLogLibdvdcss(_ path: String) -> String {
        String(format: localized("libdvdcss: %@"), path)
    }

    nonisolated static func ripLogPreset(_ path: String) -> String {
        String(format: localized("Preset: %@"), path)
    }

    nonisolated static func ripLogCommand(executablePath: String, arguments: String) -> String {
        String(format: localized("Command: %@ %@"), executablePath, arguments)
    }

    nonisolated static func ripLogExitCode(_ exitCode: Int32) -> String {
        String(format: localized("Exit code: %d"), exitCode)
    }

    nonisolated static func ripLogOutcome(_ outcome: String) -> String {
        String(format: localized("Outcome: %@"), outcome)
    }

    nonisolated static func ripLogFinished(_ finishedAt: String) -> String {
        String(format: localized("Finished: %@"), finishedAt)
    }

    nonisolated static func ripLogElapsed(_ elapsed: String) -> String {
        String(format: localized("Elapsed: %@"), elapsed)
    }

    nonisolated static func ripLogElapsedSeconds(_ seconds: Double) -> String {
        String(format: localized("%.2f seconds"), seconds)
    }

    nonisolated static func ripLogSelectedDVD(_ dvdName: String) -> String {
        String(format: localized("%@: Selected DVD: %@"), RipConfiguration.appName, dvdName)
    }

    nonisolated static func ripLogOutputFile(_ path: String) -> String {
        String(format: localized("%@: Output file: %@"), RipConfiguration.appName, path)
    }

    nonisolated static func ripLogStartedRipping(_ dvdName: String) -> String {
        String(format: localized("%@: Started ripping %@"), RipConfiguration.appName, dvdName)
    }

    nonisolated static func ripLogCompletedOutputProtected(_ path: String) -> String {
        String(format: localized("Completed output protected from cancellation cleanup: %@"), path)
    }

    nonisolated static func ripLogOutputPreserved(_ path: String) -> String {
        String(format: localized("Output preserved for inspection: %@"), path)
    }

    nonisolated static func ripLogRipCompletedSuccessfully() -> String {
        String(format: localized("%@: Rip completed successfully"), RipConfiguration.appName)
    }

    nonisolated static func ripLogRipFailedOutputPreserved() -> String {
        String(format: localized("%@: Rip failed; output preserved for inspection"), RipConfiguration.appName)
    }

    nonisolated static func ripLogOutputValidationFailed() -> String {
        String(format: localized("%@: Output validation failed"), RipConfiguration.appName)
    }

    nonisolated static func ripLogDeletedIncompleteOutputFile(_ path: String) -> String {
        String(format: localized("Deleted incomplete output file: %@"), path)
    }

    nonisolated static func ripLogCouldNotDeleteIncompleteOutputFile(_ errorDescription: String) -> String {
        String(format: localized("Could not delete incomplete output file: %@"), errorDescription)
    }

    nonisolated static func ripLogUserRequestedStop() -> String {
        String(format: localized("%@: User requested stop"), RipConfiguration.appName)
    }

    nonisolated static func handBrakeLaunchFailed(_ errorDescription: String) -> String {
        String(format: localized("Failed to launch HandBrakeCLI: %@"), errorDescription)
    }

    nonisolated static func handBrakeOutputReadFailed(_ errorDescription: String) -> String {
        String(format: localized("Could not read HandBrakeCLI output: %@"), errorDescription)
    }

    private nonisolated static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}
