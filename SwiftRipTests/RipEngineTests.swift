//
//  RipEngineTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct RipEngineTests {

    @Test func emitsTypedProgressEventsFromHandBrakeOutput() async throws {
        let testEnvironment = try RipTestSupport.makeRunnableTestEnvironment()
        defer { testEnvironment.cleanup() }

        let engine = RipEngine(
            configuration: testEnvironment.configuration,
            fileManager: .default,
            handBrakeRunner: RipTestSupport.StubHandBrakeRunner(
                exitCode: 0,
                outputURLToCreate: testEnvironment.outputURL
            )
        )
        let request = RipRequest(
            input: testEnvironment.dvd,
            outputURL: testEnvironment.outputURL,
            logDirectoryURL: testEnvironment.logDirectory
        )

        var progressValues: [Double] = []
        for await event in engine.events(for: request) {
            if case .progressUpdated(let progress) = event {
                progressValues.append(progress)
            }
        }

        #expect(progressValues == [1])
    }

}
