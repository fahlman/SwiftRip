//
//  RipViewModelSelectionTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct RipViewModelSelectionTests {

    @Test func suggestedOutputNameUsesSelectedDVDName() {
        let viewModel = RipTestSupport.makeViewModel()
        viewModel.selectDVD(DVDVolume(id: "/Volumes/MY_MOVIE", name: "MY_MOVIE", path: "/Volumes/MY_MOVIE"))

        #expect(viewModel.suggestedOutputName == "My Movie.m4v")
    }

    @Test func suggestedOutputNameCanUseOriginalDVDName() {
        let appSettings = RipTestSupport.makeTestAppSettings()
        appSettings.outputFilenameFormat = .originalName
        let viewModel = RipTestSupport.makeViewModel(
            appSettings: appSettings
        )
        viewModel.selectDVD(DVDVolume(id: "/Volumes/MY_MOVIE", name: "MY_MOVIE", path: "/Volumes/MY_MOVIE"))

        #expect(viewModel.suggestedOutputName == "MY_MOVIE.m4v")
    }

    @Test func suggestedOutputNameCanIncludeDate() {
        let appSettings = RipTestSupport.makeTestAppSettings()
        appSettings.outputFilenameFormat = .datedTitleCase
        let viewModel = RipTestSupport.makeViewModel(
            appSettings: appSettings
        )
        viewModel.selectDVD(DVDVolume(id: "/Volumes/MY_MOVIE", name: "MY_MOVIE", path: "/Volumes/MY_MOVIE"))

        #expect(viewModel.suggestedOutputName.hasPrefix("My Movie - "))
        #expect(viewModel.suggestedOutputName.hasSuffix(".m4v"))
    }

    @Test func setOutputURLNormalizesExtensionToM4V() {
        let viewModel = RipTestSupport.makeViewModel()
        viewModel.selectDVD(DVDVolume(id: "/Volumes/MOVIE", name: "MOVIE", path: "/Volumes/MOVIE"))
        viewModel.setOutputURL(URL(fileURLWithPath: "/tmp/Movie.mp4"))

        #expect(viewModel.outputURL?.path == "/tmp/Movie.m4v")
    }

    @Test func selectedOutputAvoidsExistingFiles() throws {
        let testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: testDirectory)
        }
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        let existingOutputURL = testDirectory.appendingPathComponent("Movie.m4v")
        try "existing movie".write(to: existingOutputURL, atomically: true, encoding: .utf8)

        let viewModel = RipTestSupport.makeViewModel()
        viewModel.selectDVD(
            DVDVolume(id: "/Volumes/MOVIE", name: "MOVIE", path: "/Volumes/MOVIE"),
            outputURL: existingOutputURL
        )

        #expect(viewModel.outputURL == testDirectory.appendingPathComponent("Movie 2.m4v"))
    }

    @Test func chooseDVDSelectsValidDVDAndDefaultsOutputToMovies() throws {
        let dvdURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("MY_MOVIE", isDirectory: true)
        let videoTSURL = dvdURL.appendingPathComponent(DVDVolume.videoTSDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: videoTSURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: dvdURL.deletingLastPathComponent())
        }

        let userDefaultsSuiteName = "RipViewModelSelectionTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: userDefaultsSuiteName))
        defer {
            userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        }
        let appSettings = AppSettings(
            userDefaults: userDefaults,
            fileManager: .default
        )
        let viewModel = RipTestSupport.makeViewModel(
            dvdInputAccessProvider: RipTestSupport.RecordingDVDInputAccessProvider(),
            appSettings: appSettings
        )
        let didChooseDVD = viewModel.chooseDVD(at: dvdURL)

        #expect(didChooseDVD)
        let moviesURL = AppSettings.defaultMoviesDirectory(using: .default)

        #expect(viewModel.selectedDVD?.name == "MY_MOVIE")
        #expect(viewModel.outputURL == moviesURL.appendingPathComponent("My Movie.m4v"))
        #expect(viewModel.commandAvailability.canRip)
        #expect(viewModel.needsOutputDirectoryPermission)
    }

    @Test func chooseDVDRejectsFolderWithoutVideoTS() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        let inputAccessProvider = RipTestSupport.RecordingDVDInputAccessProvider()
        let viewModel = RipTestSupport.makeViewModel(
            dvdInputAccessProvider: inputAccessProvider
        )
        let didChooseDVD = viewModel.chooseDVD(at: folderURL)

        #expect(!didChooseDVD)
        #expect(inputAccessProvider.startedURLs == [folderURL])
        #expect(inputAccessProvider.accesses.first?.stopCount == 1)
        #expect(viewModel.selectedDVD == nil)
        #expect(viewModel.outputURL == nil)
        #expect(!viewModel.commandAvailability.canRip)
        #expect(viewModel.primaryAction == .chooseDVD)
        #expect(viewModel.statusMessage == AppStrings.chooseVideoTSFolder(directoryName: DVDVolume.videoTSDirectoryName))
    }

    @Test func chooseDVDRejectsVideoTSFolderSelection() throws {
        let dvdURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("MOVIE", isDirectory: true)
        let videoTSURL = dvdURL.appendingPathComponent(DVDVolume.videoTSDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: videoTSURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: dvdURL.deletingLastPathComponent())
        }

        let viewModel = RipTestSupport.makeViewModel()
        let didChooseDVD = viewModel.chooseDVD(at: videoTSURL)

        #expect(!didChooseDVD)
        #expect(viewModel.selectedDVD == nil)
        #expect(viewModel.primaryAction == .chooseDVD)
        #expect(viewModel.statusMessage == AppStrings.chooseVideoTSFolder(directoryName: DVDVolume.videoTSDirectoryName))
    }

    @Test func chooseDVDReplacingSelectionStopsPreviousAccess() throws {
        let firstDVDURL = try makeDVDDirectory(named: "FIRST")
        let secondDVDURL = try makeDVDDirectory(named: "SECOND")
        defer {
            try? FileManager.default.removeItem(at: firstDVDURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: secondDVDURL.deletingLastPathComponent())
        }

        let inputAccessProvider = RipTestSupport.RecordingDVDInputAccessProvider()
        let viewModel = RipTestSupport.makeViewModel(
            dvdInputAccessProvider: inputAccessProvider
        )

        #expect(viewModel.chooseDVD(at: firstDVDURL))
        #expect(viewModel.chooseDVD(at: secondDVDURL))

        #expect(inputAccessProvider.startedURLs == [firstDVDURL, secondDVDURL])
        #expect(inputAccessProvider.accesses[0].stopCount == 1)
        #expect(inputAccessProvider.accesses[1].stopCount == 0)
        #expect(viewModel.selectedDVD?.name == "SECOND")
    }

    @Test func refreshDVDsFindsMountedDVDsWithoutSelectingThem() {
        let firstDVD = DVDVolume(id: "/Volumes/FIRST", name: "FIRST", path: "/Volumes/FIRST")
        let viewModel = RipTestSupport.makeViewModel(
            volumeFinder: RipTestSupport.StubDVDVolumeFinder(volumes: [firstDVD])
        )

        viewModel.refreshDVDs()

        #expect(viewModel.dvdVolumes == [firstDVD])
        #expect(viewModel.selectedDVD == nil)
        #expect(viewModel.dvdDisplayName == AppStrings.noValidDVDTitle)
        #expect(!viewModel.commandAvailability.canRip)
        #expect(viewModel.primaryAction == .chooseDVD)
    }

    @Test func refreshDVDsPreservesSelectedDVDWhenStillMounted() throws {
        let selectedDVD = DVDVolume(id: "/Volumes/MOVIE", name: "MOVIE", path: "/Volumes/MOVIE")
        let viewModel = RipTestSupport.makeViewModel(
            volumeFinder: RipTestSupport.StubDVDVolumeFinder(volumes: [selectedDVD])
        )
        viewModel.selectDVD(selectedDVD, outputURL: URL(fileURLWithPath: "/tmp/Custom.m4v"))

        viewModel.refreshDVDs()

        #expect(viewModel.selectedDVD == selectedDVD)
        #expect(viewModel.outputURL?.path == "/tmp/Custom.m4v")
    }

    @Test func refreshDVDsClearsStaleSelectionWithoutAuthorizingDetectedDVD() {
        let firstDVD = DVDVolume(id: "/Volumes/FIRST", name: "FIRST", path: "/Volumes/FIRST")
        let staleDVD = DVDVolume(id: "/Volumes/STALE", name: "STALE", path: "/Volumes/STALE")
        let viewModel = RipTestSupport.makeViewModel(
            volumeFinder: RipTestSupport.StubDVDVolumeFinder(volumes: [firstDVD])
        )
        viewModel.selectDVD(staleDVD)

        viewModel.refreshDVDs()

        #expect(viewModel.dvdVolumes == [firstDVD])
        #expect(viewModel.selectedDVD == nil)
        #expect(viewModel.outputURL == nil)
        #expect(viewModel.dvdDisplayName == AppStrings.noValidDVDTitle)
        #expect(!viewModel.commandAvailability.canRip)
    }

    @Test func defaultLogDirectoryUsesUserLibraryLogs() {
        let viewModel = RipTestSupport.makeViewModel()
        let expectedURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("SwiftRip", isDirectory: true)

        #expect(viewModel.defaultLogDirectory == expectedURL)
    }

    private func makeDVDDirectory(named name: String) throws -> URL {
        let dvdURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        let videoTSURL = dvdURL.appendingPathComponent(DVDVolume.videoTSDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: videoTSURL, withIntermediateDirectories: true)
        return dvdURL
    }
}
