//
//  RipConfigurationTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

struct RipConfigurationTests {

    @Test func handBrakeArgumentsContainInputOutputAndPresetOptions() {
        let presetURL = URL(fileURLWithPath: "/tmp/\(RipConfiguration.presetResourceName).\(RipConfiguration.presetFileExtension)")
        let configuration = RipConfiguration(
            handBrakeCLIPath: "/usr/local/bin/\(RipConfiguration.handBrakeCLIExecutableName)",
            libdvdcssPath: "/usr/local/lib/\(RipConfiguration.libdvdcssLibraryName)",
            presetURL: presetURL
        )
        let volume = DVDVolume(id: "/Volumes/Movie", name: "Movie", path: "/Volumes/Movie")
        let outputURL = URL(fileURLWithPath: "/tmp/Movie.m4v")

        let arguments = configuration.handBrakeArguments(input: volume, outputURL: outputURL)

        #expect(arguments == [
            "--preset-import-file", presetURL.path,
            "-Z", RipConfiguration.appName,
            "-i", "/Volumes/Movie",
            "-t", "1",
            "-o", "/tmp/Movie.m4v"
        ])
    }
}
