//
//  AppStringsTests.swift
//  SwiftRipTests
//

import Testing
@testable import SwiftRip

struct AppStringsTests {

    @Test func formatsCoreStatusMessages() {
        #expect(AppStrings.initialStatusMessage == "Choose a DVD and output file to begin.")
        #expect(AppStrings.readyToRip("Movie") == "Ready to rip Movie.")
        #expect(AppStrings.ripping("Movie") == "Ripping Movie...")
        #expect(AppStrings.ripStopped == "Rip stopped.")
        #expect(AppStrings.ripMenuTitle == "Rip")
        #expect(AppStrings.checkForUpdatesTitle == "Check for Updates…")
        #expect(AppStrings.revealOutputTitle == "Reveal Output in Finder")
        #expect(AppStrings.revealLogTitle == "Reveal Log in Finder")
        #expect(AppStrings.invalidDVDSelectionTitle == "Not a Video DVD")
        #expect(AppStrings.chooseVideoTSFolder(directoryName: "VIDEO_TS") == "Choose a folder that contains a VIDEO_TS directory.")
        #expect(AppStrings.stopRipConfirmationTitle == "Stop Rip?")
        #expect(AppStrings.stopRipConfirmationMessage == "Stopping now will terminate HandBrakeCLI and delete the incomplete output file.")
        #expect(AppStrings.keepRippingTitle == "Keep Ripping")
        #expect(AppStrings.dvdStatusAccessibilityLabel == "DVD status")
        #expect(AppStrings.progressAccessibilityLabel == "Rip progress")
        #expect(AppStrings.percentComplete(42) == "42 percent")
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
        #expect(AppStrings.chooseOutputFolderPrompt == "Choose Output Folder")
        #expect(AppStrings.outputFolderPermissionFailedTitle == "Could Not Use Output Folder")
        #expect(AppStrings.outputDirectoryMissing == "The output folder does not exist.")
        #expect(AppStrings.outputDirectoryNotFolder == "The output location is not a folder.")
        #expect(AppStrings.outputFileMissing("/tmp/Movie.m4v") == "HandBrakeCLI finished, but no output file was created at /tmp/Movie.m4v.")
        #expect(AppStrings.outputFileEmpty("/tmp/Movie.m4v") == "HandBrakeCLI finished, but the output file at /tmp/Movie.m4v is empty.")
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
