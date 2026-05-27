//
//  RipViewModelFailureTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct RipViewModelFailureTests {

    @Test func successfulExitWithoutOutputFileFailsRip() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let ripNotifier = RipTestSupport.RecordingRipNotifier()
        let viewModel = RipTestSupport.makeRunnableViewModel(
            environment: testEnvironment,
            runner: RipTestSupport.StubHandBrakeRunner(exitCode: 0, outputURLToCreate: nil),
            ripNotifier: ripNotifier
        )

        await viewModel.startRip { _ in }

        let logURL = try #require(viewModel.logFileURL)
        let logText = try String(contentsOf: logURL, encoding: .utf8)
        let expectedMessage = AppStrings.outputFileMissing(testEnvironment.outputURL.path)

        #expect(viewModel.primaryAction == .rip)
        #expect(viewModel.statusMessage.contains(expectedMessage))
        #expect(ripNotifier.failedOutputURLs == [testEnvironment.outputURL])
        #expect(ripNotifier.failureMessages == [expectedMessage])
        #expect(logText.contains("SwiftRip: Output validation failed"))
        #expect(logText.contains(expectedMessage))
        #expect(logText.contains("Outcome: Failed"))
        #expect(logText.contains("Exit code: 0"))
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

    @Test func failedRipLeavesOutputAndLogRevealableForRecovery() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let runner = RipTestSupport.StubHandBrakeRunner(
            exitCode: 4,
            outputURLToCreate: testEnvironment.outputURL
        )
        let viewModel = RipTestSupport.makeRunnableViewModel(environment: testEnvironment, runner: runner)
        await viewModel.startRip { _ in }

        #expect(FileManager.default.fileExists(atPath: testEnvironment.outputURL.path))
        #expect(viewModel.outputURL == testEnvironment.outputURL)
        #expect(viewModel.logFileURL != nil)
        #expect(viewModel.commandAvailability.canRevealOutput)
        #expect(viewModel.commandAvailability.canRevealLog)
        #expect(viewModel.statusMessage.contains("HandBrakeCLI failed with exit code 4"))
        #expect(viewModel.statusMessage.contains("Log saved to"))
        #expect(viewModel.primaryAction == .rip)
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
}
