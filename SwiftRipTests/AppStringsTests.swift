//
//  AppStringsTests.swift
//  SwiftRipTests
//
//  Created by Ryan Fahlsing on 5/17/26.
//

import Testing
@testable import SwiftRip

@MainActor
struct AppStringsTests {

    @Test func formatsCoreStatusMessages() {
        #expect(AppStrings.initialStatusMessage == "Choose a DVD and output file to begin.")
        #expect(AppStrings.readyToRip("Movie") == "Ready to rip Movie.")
        #expect(AppStrings.ripping("Movie") == "Ripping Movie...")
        #expect(AppStrings.ripStopped == "Rip stopped.")
    }

    @Test func formatsCompletionAndFailureMessages() {
        #expect(AppStrings.done(outputPath: "/tmp/Movie.m4v", logPath: "/tmp/Movie.log") == "Done. Saved to /tmp/Movie.m4v. Log saved to /tmp/Movie.log.")
        #expect(AppStrings.handBrakeFailed(exitCode: 4, logPath: "/tmp/Movie.log") == "HandBrakeCLI failed with exit code 4. Log saved to /tmp/Movie.log.")
    }

    @Test func formatsAboutMessages() {
        #expect(AppStrings.aboutTitle(appName: "SwiftRip") == "About SwiftRip")
        #expect(AppStrings.version("1.0", build: "1") == "Version 1.0 (1)")
        #expect(AppStrings.build("1") == "Build 1")
    }
}
