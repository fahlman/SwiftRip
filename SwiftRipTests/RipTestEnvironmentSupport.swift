//
//  RipTestEnvironmentSupport.swift
//  SwiftRipTests
//

import Foundation
@testable import SwiftRip

extension RipTestSupport {
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
        let presetURL = toolDirectory.appendingPathComponent(
            "\(RipConfiguration.presetResourceName).\(RipConfiguration.presetFileExtension)"
        )

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
}
