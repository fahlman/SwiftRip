//
//  RipLifecycleStateTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct RipLifecycleStateTests {

    @Test func primaryActionFollowsPhase() {
        let dvd = DVDVolume(id: "/Volumes/MOVIE", name: "MOVIE", path: "/Volumes/MOVIE")
        let outputURL = URL(fileURLWithPath: "/tmp/Movie.m4v")
        var state = RipLifecycleState()

        #expect(state.primaryAction == .chooseDVD)
        #expect(!state.hasSelectedDVD)
        #expect(state.selectedDVDName == nil)

        state.selectDVD(dvd, outputURL: outputURL, statusMessage: "Ready")
        #expect(state.primaryAction == .rip)
        #expect(state.hasSelectedDVD)
        #expect(state.selectedDVDName == "MOVIE")

        state.prepareRipSession(
            makeSession(dvd: dvd, outputURL: outputURL),
            statusMessage: "Preparing"
        )
        #expect(state.primaryAction == .stop)

        state.beginEncoding(statusMessage: "Ripping")
        #expect(state.primaryAction == .stop)

        state.markCompleted(statusMessage: "Done")
        #expect(state.primaryAction == .eject)
    }

    @Test func commandAvailabilityFollowsPhaseAndURLs() {
        let dvd = DVDVolume(id: "/Volumes/MOVIE", name: "MOVIE", path: "/Volumes/MOVIE")
        let outputURL = URL(fileURLWithPath: "/tmp/Movie.m4v")
        var state = RipLifecycleState()

        #expect(state.commandAvailability == RipCommandAvailability(
            canChooseDVD: true,
            canRip: false,
            canStop: false,
            canEject: false,
            canRevealOutput: false,
            canRevealLog: false
        ))

        state.selectDVD(dvd, outputURL: outputURL, statusMessage: "Ready")
        #expect(state.commandAvailability == RipCommandAvailability(
            canChooseDVD: true,
            canRip: true,
            canStop: false,
            canEject: false,
            canRevealOutput: true,
            canRevealLog: false
        ))

        state.prepareRipSession(
            makeSession(dvd: dvd, outputURL: outputURL),
            statusMessage: "Preparing"
        )
        #expect(state.commandAvailability == RipCommandAvailability(
            canChooseDVD: false,
            canRip: false,
            canStop: true,
            canEject: false,
            canRevealOutput: true,
            canRevealLog: true
        ))

        state.beginEncoding(statusMessage: "Ripping")
        #expect(state.commandAvailability.canRip == false)
        #expect(state.commandAvailability.canStop == true)
        #expect(state.commandAvailability.canEject == false)

        state.markCompleted(statusMessage: "Done")
        #expect(state.commandAvailability.canRip == false)
        #expect(state.commandAvailability.canStop == false)
        #expect(state.commandAvailability.canEject == true)
    }

    private func makeSession(dvd: DVDVolume, outputURL: URL) -> RipSession {
        RipSession(
            input: dvd,
            outputURL: outputURL,
            arguments: [],
            logDirectoryURL: FileManager.default.temporaryDirectory,
            executablePath: "/tmp/HandBrakeCLI",
            libdvdcssPath: "/tmp/libdvdcss.2.dylib",
            presetURL: URL(fileURLWithPath: "/tmp/SwiftRip.json")
        )
    }
}
