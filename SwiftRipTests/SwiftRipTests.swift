//
//  SwiftRipTests.swift
//  SwiftRipTests
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct RipViewModelSelectionTests {

    @Test func suggestedOutputNameUsesSelectedDVDName() {
        let viewModel = RipViewModel()
        viewModel.selectedDVD = DVDVolume(id: "/Volumes/MY_MOVIE", name: "MY_MOVIE", path: "/Volumes/MY_MOVIE")

        #expect(viewModel.suggestedOutputName == "My Movie.m4v")
    }

    @Test func setOutputURLNormalizesExtensionToM4V() {
        let viewModel = RipViewModel()
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

        let viewModel = RipViewModel()
        viewModel.chooseDVD(at: dvdURL)

        let moviesURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies", isDirectory: true)

        #expect(viewModel.selectedDVD?.name == "MY_MOVIE")
        #expect(viewModel.outputURL == moviesURL.appendingPathComponent("My Movie.m4v"))
        #expect(viewModel.isPrimaryActionAvailable)
    }

    @Test func chooseDVDRejectsFolderWithoutVideoTS() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: folderURL)
        }

        let viewModel = RipViewModel()
        viewModel.chooseDVD(at: folderURL)

        #expect(viewModel.selectedDVD == nil)
        #expect(viewModel.outputURL == nil)
        #expect(!viewModel.isPrimaryActionAvailable)
    }

    @Test func defaultLogDirectoryUsesUserLibraryLogs() {
        let viewModel = RipViewModel()
        let expectedURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("SwiftRip", isDirectory: true)

        #expect(viewModel.defaultLogDirectory == expectedURL)
    }
}
