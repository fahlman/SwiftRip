//
//  HandBrakeProgressParserTests.swift
//  SwiftRipTests
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Testing
@testable import SwiftRip

@MainActor
struct HandBrakeProgressParserTests {

    @Test func parsesProgressPercentage() {
        let progress = HandBrakeProgressParser.progressValue(
            from: "Encoding: task 1 of 1, 42.50 %"
        )

        #expect(progress == 0.425)
    }

    @Test func parsesLastProgressWhenChunkContainsMultipleUpdates() {
        let progress = HandBrakeProgressParser.progressValue(
            from: "Encoding: task 1 of 1, 12.00 %\nEncoding: task 1 of 1, 45.00 %"
        )

        #expect(progress == 0.45)
    }

    @Test func ignoresMalformedProgress() {
        let progress = HandBrakeProgressParser.progressValue(from: "Scanning title 1")

        #expect(progress == nil)
    }

    @Test func clampsProgressAboveOne() {
        let progress = HandBrakeProgressParser.progressValue(
            from: "Encoding: task 1 of 1, 150.00 %"
        )

        #expect(progress == 1)
    }
}
