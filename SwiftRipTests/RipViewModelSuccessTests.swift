//
//  RipViewModelSuccessTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct RipViewModelSuccessTests {

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

    @Test func successfulRipStopsDVDInputAccess() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let inputAccessProvider = RipTestSupport.RecordingDVDInputAccessProvider()
        let viewModel = RipTestSupport.makeViewModel(
            configuration: testEnvironment.configuration,
            handBrakeRunner: RipTestSupport.StubHandBrakeRunner(
                exitCode: 0,
                outputURLToCreate: testEnvironment.outputURL
            ),
            dvdInputAccessProvider: inputAccessProvider,
            logDirectoryOverride: testEnvironment.logDirectory
        )

        #expect(viewModel.chooseDVD(at: URL(fileURLWithPath: testEnvironment.dvd.path, isDirectory: true)))
        viewModel.setOutputURL(testEnvironment.outputURL)
        await viewModel.startRip { _ in }

        #expect(inputAccessProvider.accesses.first?.stopCount == 1)
        #expect(viewModel.primaryAction == .eject)
    }

    @Test func outputCreatedAfterSelectionIsNotOverwritten() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let runner = RipTestSupport.ArgumentOutputCreatingHandBrakeRunner()
        let viewModel = RipTestSupport.makeRunnableViewModel(environment: testEnvironment, runner: runner)
        try "existing output".write(to: testEnvironment.outputURL, atomically: true, encoding: .utf8)

        await viewModel.startRip { _ in }

        let expectedOutputURL = testEnvironment.rootURL.appendingPathComponent("Movie 2.m4v")
        let originalOutputText = try String(contentsOf: testEnvironment.outputURL, encoding: .utf8)

        #expect(viewModel.outputURL == expectedOutputURL)
        #expect(runner.outputURLs == [expectedOutputURL])
        #expect(originalOutputText == "existing output")
        #expect(FileManager.default.fileExists(atPath: expectedOutputURL.path))
        #expect(viewModel.primaryAction == .eject)
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

        await viewModel.startRip { _ in }

        #expect(FileManager.default.fileExists(atPath: testEnvironment.outputURL.path))
        #expect(viewModel.primaryAction == .eject)
        #expect(viewModel.statusMessage == "Could not eject disc")
    }
}
