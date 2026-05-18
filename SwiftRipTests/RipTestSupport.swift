//
//  RipTestSupport.swift
//  SwiftRipTests
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Foundation
@testable import SwiftRip

enum RipTestSupport {

    @MainActor
    static func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if condition() {
                return
            }

            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @MainActor
    static func makeRunnableViewModel(
        environment: RunnableTestEnvironment,
        runner: HandBrakeRunning,
        appSettings: AppSettings? = nil,
        completionNotifier: RipCompletionNotifying = NoOpRipCompletionNotifier()
    ) -> RipViewModel {
        let resolvedAppSettings = appSettings ?? makeTestAppSettings()
        let viewModel = RipViewModel(
            configuration: environment.configuration,
            fileManager: .default,
            handBrakeRunner: runner,
            volumeFinder: FileSystemDVDVolumeFinder(),
            appSettings: resolvedAppSettings,
            completionNotifier: completionNotifier,
            logDirectoryOverride: environment.logDirectory
        )

        viewModel.selectDVD(environment.dvd, outputURL: environment.outputURL)
        return viewModel
    }

    @MainActor
    static func makeTestAppSettings() -> AppSettings {
        let suiteName = "SwiftRipTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)
        return AppSettings(userDefaults: userDefaults, fileManager: .default)
    }

    static func makeRunnableTestEnvironment() throws -> RunnableTestEnvironment {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let toolDirectory = rootURL.appendingPathComponent("Tools", isDirectory: true)
        let dvdURL = rootURL.appendingPathComponent("Movie", isDirectory: true)
        let videoTSURL = dvdURL.appendingPathComponent(DVDVolume.videoTSDirectoryName, isDirectory: true)
        let outputURL = rootURL.appendingPathComponent("Movie.m4v")
        let logDirectory = rootURL.appendingPathComponent("Logs", isDirectory: true)
        let handBrakeURL = toolDirectory.appendingPathComponent(RipConfiguration.handBrakeCLIExecutableName)
        let libdvdcssURL = toolDirectory.appendingPathComponent(RipConfiguration.libdvdcssLibraryName)
        let presetURL = toolDirectory.appendingPathComponent("\(RipConfiguration.presetResourceName).\(RipConfiguration.presetFileExtension)")

        try FileManager.default.createDirectory(at: toolDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: videoTSURL, withIntermediateDirectories: true)
        try "tool".write(to: handBrakeURL, atomically: true, encoding: .utf8)
        try "library".write(to: libdvdcssURL, atomically: true, encoding: .utf8)
        try "{}".write(to: presetURL, atomically: true, encoding: .utf8)

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: handBrakeURL.path
        )

        return RunnableTestEnvironment(
            rootURL: rootURL,
            configuration: RipConfiguration(
                handBrakeCLIPath: handBrakeURL.path,
                libdvdcssPath: libdvdcssURL.path,
                presetURL: presetURL
            ),
            dvd: DVDVolume(id: dvdURL.path, name: dvdURL.lastPathComponent, path: dvdURL.path),
            outputURL: outputURL,
            logDirectory: logDirectory
        )
    }

    struct RunnableTestEnvironment {
        let rootURL: URL
        let configuration: RipConfiguration
        let dvd: DVDVolume
        let outputURL: URL
        let logDirectory: URL

        func cleanup() {
            try? FileManager.default.removeItem(at: rootURL)
        }
    }

    struct StubHandBrakeRunner: HandBrakeRunning {
        let exitCode: Int32
        let outputURLToCreate: URL?

        func run(
            executablePath: String,
            arguments: [String],
            onOutput: @escaping @MainActor @Sendable (String) -> Void
        ) async -> HandBrakeResult {
            onOutput("Encoding: task 1 of 1, 100.00 %\n")

            if let outputURLToCreate {
                try? "partial-or-complete output".write(to: outputURLToCreate, atomically: true, encoding: .utf8)
            }

            return HandBrakeResult(exitCode: exitCode)
        }
    }

    struct StubDVDVolumeFinder: DVDVolumeFinding {
        let volumes: [DVDVolume]

        func findMountedDVDs() -> [DVDVolume] {
            volumes
        }
    }

    struct NoOpRipCompletionNotifier: RipCompletionNotifying {
        func notifyRipCompleted(
            outputURL: URL,
            sound: CompletionSound,
            isNotificationEnabled: Bool,
            logError: @escaping @MainActor @Sendable (String) -> Void
        ) {}
    }

    @MainActor
    final class RecordingRipCompletionNotifier: RipCompletionNotifying {
        private(set) var completedOutputURLs: [URL] = []
        private(set) var completionSounds: [CompletionSound] = []
        private(set) var notificationEnabledValues: [Bool] = []

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
    }

    final class WaitingHandBrakeRunner: HandBrakeRunning {
        func run(
            executablePath: String,
            arguments: [String],
            onOutput: @escaping @MainActor @Sendable (String) -> Void
        ) async -> HandBrakeResult {
            onOutput("Encoding: task 1 of 1, 1.00 %\n")

            for _ in 0..<100 {
                if Task.isCancelled { break }
                try? await Task.sleep(for: .milliseconds(10))
            }

            onOutput("Canceled.\n")
            return HandBrakeResult(exitCode: -15)
        }
    }
}
