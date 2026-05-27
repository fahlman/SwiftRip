//
//  RipTestSupport.swift
//  SwiftRipTests
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
    static func makeViewModel(
        configuration: RipConfiguration = .production,
        fileManager: FileManager = .default,
        handBrakeRunner: HandBrakeRunning = StubHandBrakeRunner(exitCode: 0, outputURLToCreate: nil),
        volumeFinder: DVDVolumeFinding = FileSystemDVDVolumeFinder(),
        dvdInputAccessProvider: any DVDInputAccessProviding = NoOpDVDInputAccessProvider(),
        appSettings: AppSettings? = nil,
        ripNotifier: RipNotifying = NoOpRipNotifier(),
        dvdDeviceEjector: DVDDeviceEjecting = NoOpDVDDeviceEjector(),
        logDirectoryOverride: URL? = nil
    ) -> RipViewModel {
        RipViewModel(environment: RipEnvironment(
            configuration: configuration,
            fileManager: fileManager,
            handBrakeRunner: handBrakeRunner,
            volumeFinder: volumeFinder,
            dvdInputAccessProvider: dvdInputAccessProvider,
            appSettings: appSettings ?? makeTestAppSettings(),
            ripNotifier: ripNotifier,
            dvdDeviceEjector: dvdDeviceEjector,
            logDirectoryOverride: logDirectoryOverride
        ))
    }

    @MainActor
    static func makeRunnableViewModel(
        environment: RunnableTestEnvironment,
        runner: HandBrakeRunning,
        appSettings: AppSettings? = nil,
        ripNotifier: RipNotifying = NoOpRipNotifier(),
        dvdDeviceEjector: DVDDeviceEjecting = NoOpDVDDeviceEjector()
    ) -> RipViewModel {
        let viewModel = RipViewModel(environment: RipEnvironment(
            configuration: environment.configuration,
            fileManager: .default,
            handBrakeRunner: runner,
            volumeFinder: FileSystemDVDVolumeFinder(),
            dvdInputAccessProvider: NoOpDVDInputAccessProvider(),
            appSettings: appSettings ?? makeTestAppSettings(),
            ripNotifier: ripNotifier,
            dvdDeviceEjector: dvdDeviceEjector,
            logDirectoryOverride: environment.logDirectory
        ))

        viewModel.selectDVD(environment.dvd, outputURL: environment.outputURL)
        return viewModel
    }

    @MainActor
    static func makeTestAppSettings() -> AppSettings {
        let suiteName = "SwiftRipTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)
        return AppSettings(
            userDefaults: userDefaults,
            fileManager: .default
        )
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

    @MainActor
    final class RecordingDVDInputAccessProvider: DVDInputAccessProviding {
        private(set) var startedURLs: [URL] = []
        private(set) var accesses: [RecordingDVDInputAccess] = []

        func startAccessingDVD(at url: URL) -> any DVDInputAccess {
            let access = RecordingDVDInputAccess(url: url)
            startedURLs.append(url)
            accesses.append(access)
            return access
        }
    }

    @MainActor
    final class RecordingDVDInputAccess: DVDInputAccess {
        let url: URL
        private(set) var stopCount = 0

        init(url: URL) {
            self.url = url
        }

        func stopAccessing() {
            stopCount += 1
        }
    }

    @MainActor
    final class NoOpDVDInputAccessProvider: DVDInputAccessProviding {
        func startAccessingDVD(at url: URL) -> any DVDInputAccess {
            NoOpDVDInputAccess(url: url)
        }
    }

    @MainActor
    final class NoOpDVDInputAccess: DVDInputAccess {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func stopAccessing() {}
    }

    struct NoOpRipNotifier: RipNotifying {
        func notifyRipCompleted(
            outputURL: URL,
            sound: CompletionSound,
            isNotificationEnabled: Bool,
            logError: @escaping @MainActor @Sendable (String) -> Void
        ) {}

        func notifyRipFailed(
            outputURL: URL,
            exitCode: Int32,
            isNotificationEnabled: Bool,
            logError: @escaping @MainActor @Sendable (String) -> Void
        ) {}

        func notifyRipFailed(
            outputURL: URL,
            message: String,
            isNotificationEnabled: Bool,
            logError: @escaping @MainActor @Sendable (String) -> Void
        ) {}
    }

    @MainActor
    final class RecordingRipNotifier: RipNotifying {
        private(set) var completedOutputURLs: [URL] = []
        private(set) var completionSounds: [CompletionSound] = []
        private(set) var notificationEnabledValues: [Bool] = []
        private(set) var failedOutputURLs: [URL] = []
        private(set) var failureExitCodes: [Int32] = []
        private(set) var failureMessages: [String] = []
        private(set) var failureNotificationEnabledValues: [Bool] = []

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

        func notifyRipFailed(
            outputURL: URL,
            exitCode: Int32,
            isNotificationEnabled: Bool,
            logError: @escaping @MainActor @Sendable (String) -> Void
        ) {
            failedOutputURLs.append(outputURL)
            failureExitCodes.append(exitCode)
            failureNotificationEnabledValues.append(isNotificationEnabled)
        }

        func notifyRipFailed(
            outputURL: URL,
            message: String,
            isNotificationEnabled: Bool,
            logError: @escaping @MainActor @Sendable (String) -> Void
        ) {
            failedOutputURLs.append(outputURL)
            failureMessages.append(message)
            failureNotificationEnabledValues.append(isNotificationEnabled)
        }
    }

    struct NoOpDVDDeviceEjector: DVDDeviceEjecting {
        func ejectDVD(at url: URL) throws {}
    }

    struct ThrowingDVDDeviceEjector: DVDDeviceEjecting {
        let errorDescription: String

        func ejectDVD(at url: URL) throws {
            throw NSError(
                domain: "SwiftRipTests.ThrowingDVDDeviceEjector",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: errorDescription]
            )
        }
    }

    @MainActor
    final class RecordingDVDDeviceEjector: DVDDeviceEjecting {
        private(set) var ejectedURLs: [URL] = []

        func ejectDVD(at url: URL) throws {
            ejectedURLs.append(url)
        }
    }

    final class WaitingHandBrakeRunner: HandBrakeRunning {
        func run(
            executablePath: String,
            arguments: [String],
            onOutput: @escaping @MainActor @Sendable (String) -> Void
        ) async -> HandBrakeResult {
            onOutput("Encoding: task 1 of 1, 1.00 %\n")
            if let outputURL = Self.outputURL(from: arguments) {
                try? "incomplete output".write(to: outputURL, atomically: true, encoding: .utf8)
            }

            for _ in 0..<100 {
                if Task.isCancelled { break }
                try? await Task.sleep(for: .milliseconds(10))
            }

            onOutput("Canceled.\n")
            return HandBrakeResult(exitCode: -15)
        }

        private static func outputURL(from arguments: [String]) -> URL? {
            guard let outputFlagIndex = arguments.firstIndex(of: "-o") else { return nil }
            let outputPathIndex = arguments.index(after: outputFlagIndex)
            guard arguments.indices.contains(outputPathIndex) else { return nil }

            return URL(fileURLWithPath: arguments[outputPathIndex])
        }
    }

    @MainActor
    final class RecordingHandBrakeRunner: HandBrakeRunning {
        private(set) var runCount = 0

        func run(
            executablePath: String,
            arguments: [String],
            onOutput: @escaping @MainActor @Sendable (String) -> Void
        ) async -> HandBrakeResult {
            runCount += 1
            return HandBrakeResult(exitCode: 0)
        }
    }

    @MainActor
    final class CountingWaitingHandBrakeRunner: HandBrakeRunning {
        private(set) var runCount = 0

        func run(
            executablePath: String,
            arguments: [String],
            onOutput: @escaping @MainActor @Sendable (String) -> Void
        ) async -> HandBrakeResult {
            runCount += 1
            onOutput("Encoding: task 1 of 1, 1.00 %\n")
            if let outputURL = outputURL(from: arguments) {
                try? "incomplete output".write(to: outputURL, atomically: true, encoding: .utf8)
            }

            for _ in 0..<100 {
                if Task.isCancelled { break }
                try? await Task.sleep(for: .milliseconds(10))
            }

            return HandBrakeResult(exitCode: -15)
        }

        private func outputURL(from arguments: [String]) -> URL? {
            guard let outputFlagIndex = arguments.firstIndex(of: "-o") else { return nil }
            let outputPathIndex = arguments.index(after: outputFlagIndex)
            guard arguments.indices.contains(outputPathIndex) else { return nil }

            return URL(fileURLWithPath: arguments[outputPathIndex])
        }
    }

    @MainActor
    final class ArgumentOutputCreatingHandBrakeRunner: HandBrakeRunning {
        private(set) var outputURLs: [URL] = []

        func run(
            executablePath: String,
            arguments: [String],
            onOutput: @escaping @MainActor @Sendable (String) -> Void
        ) async -> HandBrakeResult {
            onOutput("Encoding: task 1 of 1, 100.00 %\n")

            guard let outputURL = outputURL(from: arguments) else {
                return HandBrakeResult(exitCode: 2)
            }

            outputURLs.append(outputURL)
            try? "complete output".write(to: outputURL, atomically: true, encoding: .utf8)
            return HandBrakeResult(exitCode: 0)
        }

        private func outputURL(from arguments: [String]) -> URL? {
            guard let outputFlagIndex = arguments.firstIndex(of: "-o") else { return nil }
            let outputPathIndex = arguments.index(after: outputFlagIndex)
            guard arguments.indices.contains(outputPathIndex) else { return nil }

            return URL(fileURLWithPath: arguments[outputPathIndex])
        }
    }
}
