//
//  AppLaunchConfigurationTests.swift
//  SwiftRipTests
//

import Testing
@testable import SwiftRip

struct AppLaunchConfigurationTests {

    @Test func environmentValueTakesPrecedenceOverArguments() {
        let value = AppLaunchConfiguration.value(
            for: "SWIFTRIP_TEST_KEY",
            environment: ["SWIFTRIP_TEST_KEY": "environment"],
            arguments: ["SwiftRip", "--SWIFTRIP_TEST_KEY=argument"]
        )

        #expect(value == "environment")
    }

    @Test func parsesSupportedArgumentForms() {
        let arguments = [
            "SwiftRip",
            "--DOUBLE_EQUALS=one",
            "--DOUBLE_SEPARATE", "two",
            "-SINGLE_EQUALS=three",
            "-SINGLE_SEPARATE", "four",
            "BARE_EQUALS=five",
            "BARE_SEPARATE", "six"
        ]

        #expect(AppLaunchConfiguration.value(for: "DOUBLE_EQUALS", environment: [:], arguments: arguments) == "one")
        #expect(AppLaunchConfiguration.value(for: "DOUBLE_SEPARATE", environment: [:], arguments: arguments) == "two")
        #expect(AppLaunchConfiguration.value(for: "SINGLE_EQUALS", environment: [:], arguments: arguments) == "three")
        #expect(AppLaunchConfiguration.value(for: "SINGLE_SEPARATE", environment: [:], arguments: arguments) == "four")
        #expect(AppLaunchConfiguration.value(for: "BARE_EQUALS", environment: [:], arguments: arguments) == "five")
        #expect(AppLaunchConfiguration.value(for: "BARE_SEPARATE", environment: [:], arguments: arguments) == "six")
    }

    @Test func missingBooleanArgumentValueDefaultsToEnabled() {
        #expect(AppLaunchConfiguration.isEnabled(
            "SWIFTRIP_TEST_FLAG",
            environment: [:],
            arguments: ["SwiftRip", "--SWIFTRIP_TEST_FLAG"]
        ))
    }

    @Test func detectsXCTestLaunchConfiguration() {
        #expect(AppLaunchConfiguration.isRunningUnderXCTest(
            environment: ["XCTestConfigurationFilePath": "/tmp/session.xctestconfiguration"],
            arguments: ["SwiftRip"],
            bundlePaths: []
        ))
        #expect(AppLaunchConfiguration.isRunningUnderXCTest(
            environment: ["XCInjectBundle": "/tmp/SwiftRipTests.xctest"],
            arguments: ["SwiftRip"],
            bundlePaths: []
        ))
        #expect(AppLaunchConfiguration.isRunningUnderXCTest(
            environment: [:],
            arguments: ["SwiftRip", "-XCTest", "/tmp/SwiftRipTests.xctest"],
            bundlePaths: []
        ))
        #expect(AppLaunchConfiguration.isRunningUnderXCTest(
            environment: [:],
            arguments: ["SwiftRip"],
            bundlePaths: ["/tmp/SwiftRipTests.xctest"]
        ))
        #expect(!AppLaunchConfiguration.isRunningUnderXCTest(
            environment: [:],
            arguments: ["SwiftRip"],
            bundlePaths: []
        ))
    }

}
