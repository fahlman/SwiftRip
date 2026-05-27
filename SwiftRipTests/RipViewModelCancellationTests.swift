//
//  RipViewModelCancellationTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct RipViewModelCancellationTests {

    @Test func liveLogIsWrittenDuringActiveRip() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let runner = RipTestSupport.WaitingHandBrakeRunner()
        let viewModel = RipTestSupport.makeRunnableViewModel(environment: testEnvironment, runner: runner)

        let ripTask = Task {
            await viewModel.startRip { _ in }
        }

        await RipTestSupport.waitUntil {
            guard let logFileURL = viewModel.logFileURL else { return false }
            return FileManager.default.fileExists(atPath: logFileURL.path)
        }

        let logURL = try #require(viewModel.logFileURL)
        let logText = try String(contentsOf: logURL, encoding: .utf8)

        #expect(logText.contains("SwiftRip: Started ripping Movie"))
        #expect(logText.contains("Encoding: task 1 of 1, 1.00 %"))
        #expect(viewModel.commandAvailability.canRevealLog)

        viewModel.cancelRip()
        await ripTask.value
    }

    @Test func chooseDVDDuringActiveRipIsIgnored() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }
        let otherDVDURL = testEnvironment.rootURL.appendingPathComponent("Other", isDirectory: true)
        try FileManager.default.createDirectory(
            at: otherDVDURL.appendingPathComponent(DVDVolume.videoTSDirectoryName, isDirectory: true),
            withIntermediateDirectories: true
        )

        let runner = RipTestSupport.WaitingHandBrakeRunner()
        let viewModel = RipTestSupport.makeRunnableViewModel(environment: testEnvironment, runner: runner)
        let originalDVD = viewModel.selectedDVD
        let ripTask = Task {
            await viewModel.startRip { _ in }
        }

        await RipTestSupport.waitUntil { viewModel.progress > 0 }
        let didChooseDVD = viewModel.chooseDVD(at: otherDVDURL)

        #expect(!didChooseDVD)
        #expect(!viewModel.commandAvailability.canChooseDVD)
        #expect(viewModel.selectedDVD == originalDVD)

        viewModel.cancelRip()
        await ripTask.value
    }

    @Test func doubleStartDoesNotLaunchSecondRip() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let runner = RipTestSupport.CountingWaitingHandBrakeRunner()
        let viewModel = RipTestSupport.makeRunnableViewModel(environment: testEnvironment, runner: runner)
        let firstRipTask = Task {
            await viewModel.startRip { _ in }
        }

        await RipTestSupport.waitUntil { runner.runCount == 1 }
        let secondRipTask = Task {
            await viewModel.startRip { _ in }
        }
        try? await Task.sleep(for: .milliseconds(50))

        #expect(runner.runCount == 1)

        viewModel.cancelRip()
        await firstRipTask.value
        await secondRipTask.value
    }

    @Test func cancelRipDeletesIncompleteOutputFile() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let runner = RipTestSupport.WaitingHandBrakeRunner()
        let viewModel = RipTestSupport.makeRunnableViewModel(environment: testEnvironment, runner: runner)
        let outputURL = testEnvironment.outputURL
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

    @Test func cancelAfterSuccessfulRipDoesNotDeleteCompletedOutputFile() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let runner = RipTestSupport.StubHandBrakeRunner(
            exitCode: 0,
            outputURLToCreate: testEnvironment.outputURL
        )
        let viewModel = RipTestSupport.makeRunnableViewModel(environment: testEnvironment, runner: runner)
        await viewModel.startRip { _ in }
        viewModel.cancelRip()

        #expect(FileManager.default.fileExists(atPath: testEnvironment.outputURL.path))
        #expect(viewModel.primaryAction == .eject)
    }

    @Test func windowCloseOrAppQuitCancelsRipAndDeletesIncompleteOutputFile() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let runner = RipTestSupport.WaitingHandBrakeRunner()
        let viewModel = RipTestSupport.makeRunnableViewModel(environment: testEnvironment, runner: runner)
        let ripTask = Task {
            await viewModel.startRip { _ in }
        }
        await RipTestSupport.waitUntil { viewModel.progress > 0 }

        viewModel.cancelRipForWindowCloseOrAppQuit()
        await ripTask.value

        let logURL = try #require(viewModel.logFileURL)
        let logText = try String(contentsOf: logURL, encoding: .utf8)

        #expect(!FileManager.default.fileExists(atPath: testEnvironment.outputURL.path))
        #expect(logText.contains("Outcome: Canceled"))
        #expect(!viewModel.isEncoding)
    }
}
