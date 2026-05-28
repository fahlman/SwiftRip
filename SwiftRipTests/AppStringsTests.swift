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
        #expect(AppStrings.percentDisplay(42) == "42%")
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

    @Test func formatsRipLogMessages() {
        #expect(AppStrings.ripLogOutcomeCompleted == "Completed")
        #expect(AppStrings.ripLogOutcomeFailed == "Failed")
        #expect(AppStrings.ripLogOutcomeCanceled == "Canceled")
        #expect(AppStrings.ripLogOutcomePreflightFailed == "Preflight failed")
        #expect(AppStrings.ripLogFallbackDVDName == "DVD")
        #expect(AppStrings.ripLogSelectedDVD("Movie") == "SwiftRip: Selected DVD: Movie")
        #expect(AppStrings.ripLogOutputFile("/tmp/Movie.m4v") == "SwiftRip: Output file: /tmp/Movie.m4v")
        #expect(AppStrings.ripLogStartedRipping("Movie") == "SwiftRip: Started ripping Movie")
        #expect(AppStrings.ripLogRipCompletedSuccessfully() == "SwiftRip: Rip completed successfully")
        #expect(
            AppStrings.ripLogCompletedOutputProtected("/tmp/Movie.m4v")
                == "Completed output protected from cancellation cleanup: /tmp/Movie.m4v"
        )
        #expect(AppStrings.ripLogRipFailedOutputPreserved() == "SwiftRip: Rip failed; output preserved for inspection")
        #expect(AppStrings.ripLogOutputPreserved("/tmp/Movie.m4v") == "Output preserved for inspection: /tmp/Movie.m4v")
        #expect(AppStrings.ripLogOutputValidationFailed() == "SwiftRip: Output validation failed")
        #expect(AppStrings.ripLogDeletedIncompleteOutputFile("/tmp/Movie.m4v") == "Deleted incomplete output file: /tmp/Movie.m4v")
        #expect(
            AppStrings.ripLogCouldNotDeleteIncompleteOutputFile("Denied")
                == "Could not delete incomplete output file: Denied"
        )
        #expect(AppStrings.ripLogUserRequestedStop() == "SwiftRip: User requested stop")
        #expect(AppStrings.ripLogRipStoppedByUser == "Rip stopped by user.")
    }

    @Test func formatsRipLogHeaderMessages() {
        #expect(AppStrings.ripLogTitle(appName: "SwiftRip") == "SwiftRip Log")
        #expect(AppStrings.ripLogApp(appName: "SwiftRip", version: "1.0") == "App: SwiftRip 1.0")
        #expect(AppStrings.ripLogStarted("2026-05-28T12:00:00Z") == "Started: 2026-05-28T12:00:00Z")
        #expect(AppStrings.ripLogDVD("Movie") == "DVD: Movie")
        #expect(AppStrings.ripLogInput("/Volumes/Movie") == "Input: /Volumes/Movie")
        #expect(AppStrings.ripLogOutput("/tmp/Movie.m4v") == "Output: /tmp/Movie.m4v")
        #expect(AppStrings.ripLogHandBrakeCLI("/App/HandBrakeCLI") == "HandBrakeCLI: /App/HandBrakeCLI")
        #expect(AppStrings.ripLogLibdvdcss("/App/libdvdcss.2.dylib") == "libdvdcss: /App/libdvdcss.2.dylib")
        #expect(AppStrings.ripLogPreset("/App/SwiftRip.json") == "Preset: /App/SwiftRip.json")
        #expect(
            AppStrings.ripLogCommand(executablePath: "/App/HandBrakeCLI", arguments: "-i /Volumes/Movie")
                == "Command: /App/HandBrakeCLI -i /Volumes/Movie"
        )
        #expect(AppStrings.ripLogExitCode(0) == "Exit code: 0")
        #expect(AppStrings.ripLogOutcome("Completed") == "Outcome: Completed")
        #expect(AppStrings.ripLogFinished("2026-05-28T12:00:00Z") == "Finished: 2026-05-28T12:00:00Z")
        #expect(AppStrings.ripLogElapsed("1.23 seconds") == "Elapsed: 1.23 seconds")
        #expect(AppStrings.ripLogElapsedSeconds(1.234) == "1.23 seconds")
    }

    @Test func formatsDiagnosticMessages() {
        #expect(AppStrings.handBrakeLaunchFailed("Denied") == "Failed to launch HandBrakeCLI: Denied")
        #expect(AppStrings.handBrakeOutputReadFailed("Closed") == "Could not read HandBrakeCLI output: Closed")
        #expect(AppStrings.ripNotificationCompletionErrorPrefix == "Could not show completion notification")
        #expect(AppStrings.ripNotificationFailureErrorPrefix == "Could not show failure notification")
    }

    @Test func stringCatalogMatchesAppStrings() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appStringsURL = rootURL.appendingPathComponent("SwiftRip/Resources/AppStrings.swift")
        let catalogURL = rootURL.appendingPathComponent("SwiftRip/Resources/Localizable.xcstrings")

        let appStringsSource = try String(contentsOf: appStringsURL, encoding: .utf8)
        let expectedKeys = try localizedKeys(in: appStringsSource)
        let catalogKeys = try stringCatalogKeys(from: catalogURL)

        #expect(catalogKeys == expectedKeys)
        #expect(catalogKeys.allSatisfy { !$0.contains("â") && !$0.contains("\u{FFFD}") })
        #expect(try staleStringCatalogKeys(from: catalogURL).isEmpty)
        #expect(try stringCatalogLocales(from: catalogURL) == Self.expectedCatalogLocales)
        #expect(try stringCatalogEntriesUseMatchingFormatSpecifiers(from: catalogURL))
    }

    private static let expectedCatalogLocales: Set<String> = [
        "en",
        "es",
        "fr",
        "de",
        "ja",
        "it",
        "pt-BR",
        "nl",
        "zh-Hans",
        "ko"
    ]

    private func localizedKeys(in source: String) throws -> Set<String> {
        let regularExpression = try NSRegularExpression(
            pattern: #"localized\("((?:\\.|[^"\\])*)"\)"#
        )
        let range = NSRange(location: 0, length: (source as NSString).length)

        return try Set(regularExpression.matches(in: source, range: range).map { match in
            let escapedKey = (source as NSString).substring(with: match.range(at: 1))
            return try JSONDecoder().decode(String.self, from: Data("\"\(escapedKey)\"".utf8))
        })
    }

    private func stringCatalogKeys(from url: URL) throws -> Set<String> {
        let strings = try stringCatalogEntries(from: url)
        return Set(strings.keys)
    }

    private func staleStringCatalogKeys(from url: URL) throws -> [String] {
        let strings = try stringCatalogEntries(from: url)
        return strings.compactMap { key, value in
            guard let entry = value as? [String: Any] else { return nil }
            return entry["extractionState"] as? String == "stale" ? key : nil
        }
    }

    private func stringCatalogLocales(from url: URL) throws -> Set<String> {
        let strings = try stringCatalogEntries(from: url)
        let localeSets = try strings.values.map { value in
            let entry = try #require(value as? [String: Any])
            let localizations = try #require(entry["localizations"] as? [String: Any])
            return Set(localizations.keys)
        }

        let firstLocaleSet = try #require(localeSets.first)
        guard localeSets.allSatisfy({ $0 == firstLocaleSet }) else {
            return []
        }

        return firstLocaleSet
    }

    private func stringCatalogEntriesUseMatchingFormatSpecifiers(from url: URL) throws -> Bool {
        let strings = try stringCatalogEntries(from: url)

        for (key, value) in strings {
            let sourceSpecifiers = formatSpecifiers(in: key)
            let entry = try #require(value as? [String: Any])
            let localizations = try #require(entry["localizations"] as? [String: Any])

            for localizationValue in localizations.values {
                let localization = try #require(localizationValue as? [String: Any])
                let stringUnit = try #require(localization["stringUnit"] as? [String: Any])
                let translation = try #require(stringUnit["value"] as? String)

                guard formatSpecifiers(in: translation) == sourceSpecifiers else {
                    return false
                }
            }
        }

        return true
    }

    private func formatSpecifiers(in string: String) -> [String] {
        var specifiers: [String] = []
        var index = string.startIndex
        let conversionCharacters = Set("@dDuUxXfFeEgGcCsSp")

        while let percentIndex = string[index...].firstIndex(of: "%") {
            var specifierEndIndex = string.index(after: percentIndex)
            guard specifierEndIndex < string.endIndex else { break }

            if string[specifierEndIndex] == "%" {
                index = string.index(after: specifierEndIndex)
                continue
            }

            while specifierEndIndex < string.endIndex, !conversionCharacters.contains(string[specifierEndIndex]) {
                specifierEndIndex = string.index(after: specifierEndIndex)
            }

            guard specifierEndIndex < string.endIndex else { break }

            specifiers.append(String(string[percentIndex...specifierEndIndex]))
            index = string.index(after: specifierEndIndex)
        }

        return specifiers
    }

    private func stringCatalogEntries(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let root = try #require(jsonObject as? [String: Any])
        return try #require(root["strings"] as? [String: Any])
    }
}
