//
//  RipViewModelRipLifecycleTests.swift
//  SwiftRipTests
//
//  Created by Ryan Fahlsing on 5/16/26.
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

        let viewModel = RipViewModel(
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
        let completionNotifier = RipTestSupport.RecordingRipCompletionNotifier()
        let viewModel = RipTestSupport.makeRunnableViewModel(
            environment: testEnvironment,
            runner: runner,
            completionNotifier: completionNotifier
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
        #expect(completionNotifier.completedOutputURLs == [outputURL])
        #expect(viewModel.primaryAction == .eject)
        #expect(logText.contains("Outcome: Completed"))
        #expect(logText.contains("Completed output protected from cancellation cleanup"))
        #expect(!viewModel.isEncoding)
    }

    @Test func failedRipKeepsOutputFileForInspection() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let runner = RipTestSupport.StubHandBrakeRunner(
            exitCode: 4,
            outputURLToCreate: testEnvironment.outputURL
        )
        let viewModel = RipTestSupport.makeRunnableViewModel(environment: testEnvironment, runner: runner)
        try "failed output".write(to: testEnvironment.outputURL, atomically: true, encoding: .utf8)

        await viewModel.startRip { _ in }
        await RipTestSupport.waitUntil { viewModel.statusMessage.contains("HandBrakeCLI failed with exit code 4") }

        let logURL = try #require(viewModel.logFileURL)
        let logText = try String(contentsOf: logURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: testEnvironment.outputURL.path))
        #expect(viewModel.statusMessage.contains("HandBrakeCLI failed with exit code 4"))
        #expect(logText.contains("Outcome: Failed"))
        #expect(logText.contains("Output preserved for inspection"))
        #expect(!viewModel.isEncoding)
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
        #expect(logText.contains("Deleted incomplete output file"))
        #expect(!viewModel.isEncoding)
    }
}
