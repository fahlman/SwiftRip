//
//  RipLifecycleStateTests.swift
//  SwiftRipTests
//
//  Created by Ryan Fahlsing on 5/18/26.
//

import Foundation
import Testing
@testable import SwiftRip

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
}
