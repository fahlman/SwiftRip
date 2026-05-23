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
        store.action = .openOtherApplication(at: appURL)
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

        try manager.makeSwiftRipDefaultDVDApp()

        #expect(store.action == .openOtherApplication(at: appURL))
    }

    @Test func restoringUsesProvidedAction() throws {
        let store = InMemoryDigitalHubPreferenceStore()
        let manager = DigitalHubDefaultDVDAppPreferenceManager(
            preferenceStore: store
        )
        let previousAction = DigitalHubDVDAction(action: 105)

        try manager.restoreDVDAction(previousAction)

        #expect(store.action == previousAction)
    }

    @Test func restoringNilFallsBackToIgnore() throws {
        let store = InMemoryDigitalHubPreferenceStore()
        let manager = DigitalHubDefaultDVDAppPreferenceManager(
            preferenceStore: store
        )

        try manager.restoreDVDAction(nil)

        #expect(store.action == .ignore)
    }

    @Test func typedActionDecodesLegacyDictionaryAndPreservesOtherAppPath() throws {
        let appURL = URL(fileURLWithPath: "/Applications/SwiftRip.app", isDirectory: true)
        let action = try #require(DigitalHubDVDAction(dictionary: [
            "action": NSNumber(value: 5),
            "otherapp": [
                "_CFURLString": appURL.path,
                "_CFURLStringType": NSNumber(value: 0)
            ]
        ]))

        #expect(action == .openOtherApplication(at: appURL))
        let dictionary = action.dictionaryRepresentation
        #expect(dictionary["action"] as? Int == 5)
        let otherApp = try #require(dictionary["otherapp"] as? [String: Any])
        #expect(otherApp["_CFURLString"] as? String == appURL.path)
        #expect(otherApp["_CFURLStringType"] as? Int == 0)
    }

    private final class InMemoryDigitalHubPreferenceStore: DigitalHubPreferenceStoring, @unchecked Sendable {
        var action: DigitalHubDVDAction?

        func dvdAction() -> DigitalHubDVDAction? {
            action
        }

        func setDVDAction(_ action: DigitalHubDVDAction) throws {
            self.action = action
        }
    }
}
