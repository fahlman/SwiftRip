//
//  DefaultDVDAppPreferenceManagerTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct DefaultDVDAppPreferenceManagerTests {

    @Test func reportsEnabledWhenVideoDVDPreferencePointsAtSwiftRip() {
        let appURL = URL(fileURLWithPath: "/Applications/SwiftRip.app", isDirectory: true)
        let store = InMemoryDigitalHubPreferenceStore()
        store.dictionaries["com.apple.digihub.dvd.video.appeared"] = [
            "action": 5,
            "otherapp": [
                "_CFURLString": appURL.path,
                "_CFURLStringType": 0
            ]
        ]
        let manager = DigitalHubDefaultDVDAppPreferenceManager(
            appBundleURLProvider: { appURL },
            preferenceStore: store
        )

        #expect(manager.isSwiftRipDefaultDVDApp())
    }

    @Test func enablingWritesOpenOtherApplicationPreference() throws {
        let appURL = URL(fileURLWithPath: "/Applications/SwiftRip.app", isDirectory: true)
        let store = InMemoryDigitalHubPreferenceStore()
        let manager = DigitalHubDefaultDVDAppPreferenceManager(
            appBundleURLProvider: { appURL },
            preferenceStore: store
        )

        try manager.setSwiftRipAsDefaultDVDApp(true)

        let preference = try #require(store.dictionaries["com.apple.digihub.dvd.video.appeared"])
        #expect(preference["action"] as? Int == 5)
        let otherApp = try #require(preference["otherapp"] as? [String: Any])
        #expect(otherApp["_CFURLString"] as? String == appURL.path)
        #expect(otherApp["_CFURLStringType"] as? Int == 0)
    }

    @Test func disablingOnlyClearsPreferenceWhenItPointsAtSwiftRip() throws {
        let appURL = URL(fileURLWithPath: "/Applications/SwiftRip.app", isDirectory: true)
        let store = InMemoryDigitalHubPreferenceStore()
        store.dictionaries["com.apple.digihub.dvd.video.appeared"] = [
            "action": 5,
            "otherapp": [
                "_CFURLString": appURL.path,
                "_CFURLStringType": 0
            ]
        ]
        let manager = DigitalHubDefaultDVDAppPreferenceManager(
            appBundleURLProvider: { appURL },
            preferenceStore: store
        )

        try manager.setSwiftRipAsDefaultDVDApp(false)

        let preference = try #require(store.dictionaries["com.apple.digihub.dvd.video.appeared"])
        #expect(preference["action"] as? Int == 1)
        #expect(preference["otherapp"] == nil)
    }

    @Test func disablingDoesNotOverwriteAnotherDefaultApp() throws {
        let appURL = URL(fileURLWithPath: "/Applications/SwiftRip.app", isDirectory: true)
        let otherAppURL = URL(fileURLWithPath: "/Applications/Other.app", isDirectory: true)
        let store = InMemoryDigitalHubPreferenceStore()
        let originalPreference: [String: Any] = [
            "action": 5,
            "otherapp": [
                "_CFURLString": otherAppURL.path,
                "_CFURLStringType": 0
            ]
        ]
        store.dictionaries["com.apple.digihub.dvd.video.appeared"] = originalPreference
        let manager = DigitalHubDefaultDVDAppPreferenceManager(
            appBundleURLProvider: { appURL },
            preferenceStore: store
        )

        try manager.setSwiftRipAsDefaultDVDApp(false)

        #expect(store.dictionaries["com.apple.digihub.dvd.video.appeared"]?["action"] as? Int == 5)
        let otherApp = try #require(store.dictionaries["com.apple.digihub.dvd.video.appeared"]?["otherapp"] as? [String: Any])
        #expect(otherApp["_CFURLString"] as? String == otherAppURL.path)
    }

    private final class InMemoryDigitalHubPreferenceStore: DigitalHubPreferenceStoring, @unchecked Sendable {
        var dictionaries: [String: [String: Any]] = [:]

        func dictionary(forKey key: String) -> [String: Any]? {
            dictionaries[key]
        }

        func setDictionary(_ dictionary: [String: Any], forKey key: String) throws {
            dictionaries[key] = dictionary
        }
    }
}
