//
//  RipViewModelRipLifecycleTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct RipViewModelRipLifecycleTests {

    @Test func missingHandBrakeWritesLogFile() async throws {
        let logDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: logDirectory)
        }

        let viewModel = RipTestSupport.makeViewModel(
            configuration: RipConfiguration(
                handBrakeCLIPath: "/missing/\(RipConfiguration.handBrakeCLIExecutableName)",
                libdvdcssPath: "/missing/\(RipConfiguration.libdvdcssLibraryName)",
                presetURL: URL(fileURLWithPath: "/missing/\(RipConfiguration.presetResourceName).\(RipConfiguration.presetFileExtension)")
            ),
            fileManager: .default,
            handBrakeRunner: ProcessHandBrakeRunner(),
            volumeFinder: FileSystemDVDVolumeFinder(),
            logDirectoryOverride: logDirectory
        )
        viewModel.selectDVD(
            DVDVolume(id: "/Volumes/MY_MOVIE", name: "MY_MOVIE", path: "/Volumes/MY_MOVIE"),
            outputURL: URL(fileURLWithPath: "/tmp/My Movie.m4v")
        )

        await viewModel.startRip { _ in }

        let logURL = try #require(viewModel.logFileURL)
        let logText = try String(contentsOf: logURL, encoding: .utf8)

        #expect(logURL.deletingLastPathComponent() == logDirectory)
        #expect(logText.contains("SwiftRip Log"))
        #expect(logText.contains("Started:"))
        #expect(logText.contains("HandBrakeCLI:"))
        #expect(logText.contains("libdvdcss:"))
        #expect(logText.contains("Preset:"))
        #expect(logText.contains("HandBrakeCLI was not found"))
        #expect(logText.contains("Outcome: Preflight failed"))
        #expect(logText.contains("Finished:"))
        #expect(logText.contains("Elapsed:"))
    }

    @Test func missingLibdvdcssWritesLogFile() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }
        try FileManager.default.removeItem(atPath: testEnvironment.configuration.libdvdcssPath)

        let viewModel = RipTestSupport.makeRunnableViewModel(
            environment: testEnvironment,
            runner: RipTestSupport.StubHandBrakeRunner(exitCode: 0, outputURLToCreate: nil)
        )

        await viewModel.startRip { _ in }

        let logURL = try #require(viewModel.logFileURL)
        let logText = try String(contentsOf: logURL, encoding: .utf8)

        #expect(logText.contains("libdvdcss.2.dylib was not found"))
        #expect(logText.contains("Outcome: Preflight failed"))
        #expect(viewModel.statusMessage.contains("libdvdcss.2.dylib was not found"))
        #expect(!viewModel.isEncoding)
    }

    @Test func missingPresetWritesLogFile() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }
        try FileManager.default.removeItem(at: testEnvironment.configuration.presetURL)

        let viewModel = RipTestSupport.makeRunnableViewModel(
            environment: testEnvironment,
            runner: RipTestSupport.StubHandBrakeRunner(exitCode: 0, outputURLToCreate: nil)
        )

        await viewModel.startRip { _ in }

        let logURL = try #require(viewModel.logFileURL)
        let logText = try String(contentsOf: logURL, encoding: .utf8)

        #expect(logText.contains("SwiftRip preset was not found"))
        #expect(logText.contains("Outcome: Preflight failed"))
        #expect(viewModel.statusMessage.contains("SwiftRip preset was not found"))
        #expect(!viewModel.isEncoding)
    }

    @Test func successfulRipKeepsOutputFileAndRevealsIt() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let runner = RipTestSupport.StubHandBrakeRunner(
            exitCode: 0,
            outputURLToCreate: testEnvironment.outputURL
        )
        let ripNotifier = RipTestSupport.RecordingRipNotifier()
        let viewModel = RipTestSupport.makeRunnableViewModel(
            environment: testEnvironment,
            runner: runner,
            ripNotifier: ripNotifier
        )
        let outputURL = testEnvironment.outputURL
        var revealedURL: URL?

        try "complete output".write(to: outputURL, atomically: true, encoding: .utf8)

        await viewModel.startRip { url in
            revealedURL = url
        }
        await RipTestSupport.waitUntil { revealedURL != nil }

        let logURL = try #require(viewModel.logFileURL)
        let logText = try String(contentsOf: logURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        #expect(revealedURL == outputURL)
        #expect(ripNotifier.completedOutputURLs == [outputURL])
        #expect(viewModel.primaryAction == .eject)
        #expect(logText.contains("Outcome: Completed"))
        #expect(logText.contains("SwiftRip: Selected DVD: Movie"))
        #expect(logText.contains("SwiftRip: Output file: \(outputURL.path)"))
        #expect(logText.contains("SwiftRip: Started ripping Movie"))
        #expect(logText.contains("SwiftRip: Rip completed successfully"))
        #expect(logText.contains("Completed output protected from cancellation cleanup"))
        #expect(!viewModel.isEncoding)
    }

    @Test func successfulRipUsesCompletionPreferencesAndCanSkipReveal() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let appSettings = RipTestSupport.makeTestAppSettings()
        appSettings.completionSound = .none
        appSettings.isCompletionNotificationEnabled = false
        appSettings.shouldRevealCompletedFile = false
        let runner = RipTestSupport.StubHandBrakeRunner(
            exitCode: 0,
            outputURLToCreate: testEnvironment.outputURL
        )
        let ripNotifier = RipTestSupport.RecordingRipNotifier()
        let viewModel = RipTestSupport.makeRunnableViewModel(
            environment: testEnvironment,
            runner: runner,
            appSettings: appSettings,
            ripNotifier: ripNotifier
        )
        var revealedURL: URL?

        try "complete output".write(to: testEnvironment.outputURL, atomically: true, encoding: .utf8)

        await viewModel.startRip { url in
            revealedURL = url
        }

        #expect(revealedURL == nil)
        #expect(ripNotifier.completedOutputURLs == [testEnvironment.outputURL])
        #expect(ripNotifier.completionSounds == [.none])
        #expect(ripNotifier.notificationEnabledValues == [false])
        #expect(viewModel.primaryAction == .eject)
    }

    @Test func successfulRipCanAutoEjectDVD() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let appSettings = RipTestSupport.makeTestAppSettings()
        appSettings.shouldAutoEjectAfterSuccessfulRip = true
        let runner = RipTestSupport.StubHandBrakeRunner(
            exitCode: 0,
            outputURLToCreate: testEnvironment.outputURL
        )
        let dvdDeviceEjector = RipTestSupport.RecordingDVDDeviceEjector()
        let viewModel = RipTestSupport.makeRunnableViewModel(
            environment: testEnvironment,
            runner: runner,
            appSettings: appSettings,
            dvdDeviceEjector: dvdDeviceEjector
        )

        try "complete output".write(to: testEnvironment.outputURL, atomically: true, encoding: .utf8)

        await viewModel.startRip { _ in }

        #expect(FileManager.default.fileExists(atPath: testEnvironment.outputURL.path))
        #expect(dvdDeviceEjector.ejectedURLs == [URL(fileURLWithPath: testEnvironment.dvd.path, isDirectory: true)])
        #expect(viewModel.primaryAction == .chooseDVD)
    }

    @Test func successfulRipWithAutoEjectFailureKeepsOutputAndCompletedState() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let appSettings = RipTestSupport.makeTestAppSettings()
        appSettings.shouldAutoEjectAfterSuccessfulRip = true
        let runner = RipTestSupport.StubHandBrakeRunner(
            exitCode: 0,
            outputURLToCreate: testEnvironment.outputURL
        )
        let viewModel = RipTestSupport.makeRunnableViewModel(
            environment: testEnvironment,
            runner: runner,
            appSettings: appSettings,
            dvdDeviceEjector: RipTestSupport.ThrowingDVDDeviceEjector(errorDescription: "Could not eject disc")
        )

        try "complete output".write(to: testEnvironment.outputURL, atomically: true, encoding: .utf8)

        await viewModel.startRip { _ in }

        #expect(FileManager.default.fileExists(atPath: testEnvironment.outputURL.path))
        #expect(viewModel.primaryAction == .eject)
        #expect(viewModel.statusMessage == "Could not eject disc")
    }

    @Test func failedRipKeepsOutputFileForInspection() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let runner = RipTestSupport.StubHandBrakeRunner(
            exitCode: 4,
            outputURLToCreate: testEnvironment.outputURL
        )
        let ripNotifier = RipTestSupport.RecordingRipNotifier()
        let viewModel = RipTestSupport.makeRunnableViewModel(
            environment: testEnvironment,
            runner: runner,
            ripNotifier: ripNotifier
        )
        try "failed output".write(to: testEnvironment.outputURL, atomically: true, encoding: .utf8)

        await viewModel.startRip { _ in }
        await RipTestSupport.waitUntil { viewModel.statusMessage.contains("HandBrakeCLI failed with exit code 4") }

        let logURL = try #require(viewModel.logFileURL)
        let logText = try String(contentsOf: logURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: testEnvironment.outputURL.path))
        #expect(ripNotifier.failedOutputURLs == [testEnvironment.outputURL])
        #expect(ripNotifier.failureExitCodes == [4])
        #expect(ripNotifier.failureNotificationEnabledValues == [true])
        #expect(viewModel.statusMessage.contains("HandBrakeCLI failed with exit code 4"))
        #expect(logText.contains("Outcome: Failed"))
        #expect(logText.contains("SwiftRip: Rip failed; output preserved for inspection"))
        #expect(logText.contains("Output preserved for inspection"))
        #expect(!viewModel.isEncoding)
    }

    @Test func failedRipDoesNotAutoEjectDVD() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let appSettings = RipTestSupport.makeTestAppSettings()
        appSettings.shouldAutoEjectAfterSuccessfulRip = true
        let runner = RipTestSupport.StubHandBrakeRunner(
            exitCode: 4,
            outputURLToCreate: testEnvironment.outputURL
        )
        let dvdDeviceEjector = RipTestSupport.RecordingDVDDeviceEjector()
        let viewModel = RipTestSupport.makeRunnableViewModel(
            environment: testEnvironment,
            runner: runner,
            appSettings: appSettings,
            dvdDeviceEjector: dvdDeviceEjector
        )

        await viewModel.startRip { _ in }

        #expect(dvdDeviceEjector.ejectedURLs.isEmpty)
        #expect(viewModel.primaryAction == .rip)
    }

    @Test func failedRipUsesDisabledNotificationPreference() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let appSettings = RipTestSupport.makeTestAppSettings()
        appSettings.isCompletionNotificationEnabled = false
        let runner = RipTestSupport.StubHandBrakeRunner(
            exitCode: 4,
            outputURLToCreate: testEnvironment.outputURL
        )
        let ripNotifier = RipTestSupport.RecordingRipNotifier()
        let viewModel = RipTestSupport.makeRunnableViewModel(
            environment: testEnvironment,
            runner: runner,
            appSettings: appSettings,
            ripNotifier: ripNotifier
        )

        await viewModel.startRip { _ in }

        #expect(ripNotifier.failedOutputURLs == [testEnvironment.outputURL])
        #expect(ripNotifier.failureExitCodes == [4])
        #expect(ripNotifier.failureNotificationEnabledValues == [false])
    }

    @Test func preflightFailureDoesNotNotify() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }
        try FileManager.default.removeItem(atPath: testEnvironment.configuration.handBrakeCLIPath)

        let ripNotifier = RipTestSupport.RecordingRipNotifier()
        let viewModel = RipTestSupport.makeRunnableViewModel(
            environment: testEnvironment,
            runner: RipTestSupport.StubHandBrakeRunner(exitCode: 0, outputURLToCreate: nil),
            ripNotifier: ripNotifier
        )

        await viewModel.startRip { _ in }

        #expect(ripNotifier.completedOutputURLs.isEmpty)
        #expect(ripNotifier.failedOutputURLs.isEmpty)
        #expect(viewModel.statusMessage.contains("HandBrakeCLI was not found"))
    }

    @Test func cancelRipDeletesIncompleteOutputFile() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let runner = RipTestSupport.WaitingHandBrakeRunner()
        let viewModel = RipTestSupport.makeRunnableViewModel(environment: testEnvironment, runner: runner)
        let outputURL = testEnvironment.outputURL
        try "incomplete output".write(to: outputURL, atomically: true, encoding: .utf8)

        let ripTask = Task {
            await viewModel.startRip { _ in }
        }
        await RipTestSupport.waitUntil { viewModel.progress > 0 }
        #expect(viewModel.primaryAction == .stop)
        viewModel.cancelRip()
        await ripTask.value

        let logURL = try #require(viewModel.logFileURL)
        let logText = try String(contentsOf: logURL, encoding: .utf8)

        #expect(!FileManager.default.fileExists(atPath: outputURL.path))
        #expect(logText.contains("Outcome: Canceled"))
        #expect(logText.contains("SwiftRip: User requested stop"))
        #expect(logText.contains("Deleted incomplete output file"))
        #expect(!viewModel.isEncoding)
    }

    @Test func cancelRipIsIdempotentWhileRunnerUnwinds() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let runner = RipTestSupport.WaitingHandBrakeRunner()
        let viewModel = RipTestSupport.makeRunnableViewModel(environment: testEnvironment, runner: runner)
        try "incomplete output".write(to: testEnvironment.outputURL, atomically: true, encoding: .utf8)

        let ripTask = Task {
            await viewModel.startRip { _ in }
        }
        await RipTestSupport.waitUntil { viewModel.progress > 0 }

        viewModel.cancelRip()
        viewModel.cancelRip()
        await ripTask.value

        #expect(!FileManager.default.fileExists(atPath: testEnvironment.outputURL.path))
        #expect(!viewModel.isEncoding)
    }
}
