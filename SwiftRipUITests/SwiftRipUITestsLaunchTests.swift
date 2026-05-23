//
//  SwiftRipUITestsLaunchTests.swift
//  SwiftRipUITests
//

import XCTest

final class SwiftRipUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SWIFTRIP_SUPPRESS_FIRST_RUN_OUTPUT_PROMPT"] = "1"
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
