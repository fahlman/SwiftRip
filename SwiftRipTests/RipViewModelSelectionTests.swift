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
            fileManager: .default,
            defaultDVDAppPreferenceManager: RipTestSupport.StubDefaultDVDAppPreferenceManager()
        )
        let viewModel = RipTestSupport.makeViewModel(
            appSettings: appSettings
        )
        viewModel.chooseDVD(at: dvdURL)

        let moviesURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies", isDirectory: true)

        #expect(viewModel.selectedDVD?.name == "MY_MOVIE")
        #expect(viewModel.outputURL == moviesURL.appendingPathComponent("My Movie.m4v"))
        #expect(viewModel.commandAvailability.canRip)
    }

    @Test func chooseDVDRejectsFolderWithoutVideoTS() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        let viewModel = RipTestSupport.makeViewModel()
        viewModel.chooseDVD(at: folderURL)

        #expect(viewModel.selectedDVD == nil)
        #expect(viewModel.outputURL == nil)
        #expect(!viewModel.commandAvailability.canRip)
        #expect(viewModel.primaryAction == .chooseDVD)
    }

    @Test func chooseDVDNormalizesVideoTSFolderToParentDVD() throws {
        let dvdURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("MOVIE", isDirectory: true)
        let videoTSURL = dvdURL.appendingPathComponent(DVDVolume.videoTSDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: videoTSURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: dvdURL.deletingLastPathComponent())
        }

        let viewModel = RipTestSupport.makeViewModel()
        viewModel.chooseDVD(at: videoTSURL)

        #expect(viewModel.selectedDVD == DVDVolume(id: dvdURL.path, name: "MOVIE", path: dvdURL.path))
        #expect(viewModel.outputURL?.lastPathComponent == "Movie.m4v")
        #expect(viewModel.primaryAction == .rip)
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

    @Test func refreshDVDsSelectsFirstDVDWhenSelectionIsGone() {
        let firstDVD = DVDVolume(id: "/Volumes/FIRST", name: "FIRST", path: "/Volumes/FIRST")
        let staleDVD = DVDVolume(id: "/Volumes/STALE", name: "STALE", path: "/Volumes/STALE")
        let viewModel = RipTestSupport.makeViewModel(
            volumeFinder: RipTestSupport.StubDVDVolumeFinder(volumes: [firstDVD])
        )
        viewModel.selectDVD(staleDVD)

        viewModel.refreshDVDs()

        #expect(viewModel.selectedDVD == firstDVD)
        #expect(viewModel.outputURL?.lastPathComponent == "First.m4v")
    }

    @Test func defaultLogDirectoryUsesUserLibraryLogs() {
        let viewModel = RipTestSupport.makeViewModel()
        let expectedURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("SwiftRip", isDirectory: true)

        #expect(viewModel.defaultLogDirectory == expectedURL)
    }
}
