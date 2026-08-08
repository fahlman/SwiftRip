//
//  HandBrakeProgressParserTests.swift
//  SwiftRipTests
//

import Testing
@testable import SwiftRip

struct HandBrakeProgressParserTests {

    @Test func parsesProgressPercentage() {
        let update = HandBrakeProgressParser.progressUpdate(
            from: "Encoding: task 1 of 1, 42.50 %"
        )

        #expect(update?.value == 0.425)
        #expect(update?.remainingTime == nil)
    }

    @Test func parsesProgressETA() {
        let update = HandBrakeProgressParser.progressUpdate(
            from: "Encoding: task 1 of 1, 42.50 % (30.00 fps, avg 28.00 fps, ETA 01h02m03s)"
        )

        #expect(update == HandBrakeProgressUpdate(value: 0.425, remainingTime: 3_723))
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
