//
//  AppUpdateControllerTests.swift
//  SwiftRipTests
//

import Testing
@testable import SwiftRip

struct AppUpdateControllerTests {

    @Test func sparkleConfigurationRequiresFeedURLAndPublicKey() {
        #expect(!AppUpdateController.isSparkleConfigured(feedURL: nil, publicKey: nil))
        #expect(!AppUpdateController.isSparkleConfigured(feedURL: "", publicKey: "key"))
        #expect(!AppUpdateController.isSparkleConfigured(feedURL: "https://example.com/appcast.xml", publicKey: ""))
        #expect(!AppUpdateController.isSparkleConfigured(feedURL: "   ", publicKey: "key"))
        #expect(AppUpdateController.isSparkleConfigured(feedURL: "https://example.com/appcast.xml", publicKey: "key"))
    }
}
