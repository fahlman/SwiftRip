//
//  RipLifecycleStateTests.swift
//  SwiftRipTests
//
//  Created by Ryan Fahlsing on 5/18/26.
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

        state.selectDVD(dvd, outputURL: outputURL, statusMessage: "Ready")
        #expect(state.primaryAction == .rip)

        state.beginEncoding(statusMessage: "Ripping")
        #expect(state.primaryAction == .stop)

        state.completeRip(statusMessage: "Done")
        #expect(state.primaryAction == .eject)
    }

    @Test func commandAvailabilityFollowsPhaseAndURLs() {
        let dvd = DVDVolume(id: "/Volumes/MOVIE", name: "MOVIE", path: "/Volumes/MOVIE")
        let outputURL = URL(fileURLWithPath: "/tmp/Movie.m4v")
        let logURL = URL(fileURLWithPath: "/tmp/Movie.log")
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
        state.setLogFileURL(logURL)
        #expect(state.commandAvailability == RipCommandAvailability(
            canChooseDVD: true,
            canRip: true,
            canStop: false,
            canEject: false,
            canRevealOutput: true,
            canRevealLog: true
        ))

        state.beginEncoding(statusMessage: "Ripping")
        #expect(state.commandAvailability.canRip == false)
        #expect(state.commandAvailability.canStop == true)
        #expect(state.commandAvailability.canEject == false)

        state.completeRip(statusMessage: "Done")
        #expect(state.commandAvailability.canRip == false)
        #expect(state.commandAvailability.canStop == false)
        #expect(state.commandAvailability.canEject == true)
    }
}
