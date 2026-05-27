//
//  RipViewModelPreflightTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct RipViewModelPreflightTests {

    @Test func missingHandBrakeWritesLogFile() async throws {
        let testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let logDirectory = testDirectory.appendingPathComponent("Logs", isDirectory: true)
        let outputDirectory = testDirectory.appendingPathComponent("Output", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: testDirectory)
        }
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

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
            outputURL: outputDirectory.appendingPathComponent("My Movie.m4v")
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

    @Test func outputDirectoryPreflightFailsBeforeHandBrakeRuns() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let missingOutputURL = testEnvironment.rootURL
            .appendingPathComponent("Missing", isDirectory: true)
            .appendingPathComponent("Movie.m4v")
        let runner = RipTestSupport.RecordingHandBrakeRunner()
        let viewModel = RipTestSupport.makeRunnableViewModel(environment: testEnvironment, runner: runner)
        viewModel.setOutputURL(missingOutputURL)

        await viewModel.startRip { _ in }

        let logURL = try #require(viewModel.logFileURL)
        let logText = try String(contentsOf: logURL, encoding: .utf8)

        #expect(runner.runCount == 0)
        #expect(viewModel.statusMessage.contains(AppStrings.outputDirectoryMissing))
        #expect(logText.contains(AppStrings.outputDirectoryMissing))
        #expect(logText.contains("Outcome: Preflight failed"))
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
}
