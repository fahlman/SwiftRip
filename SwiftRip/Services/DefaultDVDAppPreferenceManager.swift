//
//  DefaultDVDAppPreferenceManager.swift
//  SwiftRip
//

import Foundation

protocol DefaultDVDAppPreferenceManaging: Sendable {
    func isSwiftRipDefaultDVDApp() -> Bool
    func currentDVDAction() -> DigitalHubDVDAction?
    func makeSwiftRipDefaultDVDApp() throws
    func restoreDVDAction(_ action: DigitalHubDVDAction?) throws
}

enum DefaultDVDAppPreferenceError: LocalizedError {
    case couldNotSave
    case missingAppBundle

    var errorDescription: String? {
        switch self {
        case .couldNotSave:
            return AppStrings.defaultDVDAppSaveFailed
        case .missingAppBundle:
            return AppStrings.defaultDVDAppMissingBundle
        }
    }
}

struct DigitalHubDVDAction: Codable, Equatable, Sendable {
    static let ignore = DigitalHubDVDAction(action: DigitalHubKeys.ignoreAction)

    let action: Int
    let otherAppPath: String?

    init(action: Int, otherAppPath: String? = nil) {
        self.action = action
        self.otherAppPath = otherAppPath
    }

    init?(dictionary: [String: Any]) {
        guard let action = Self.intValue(dictionary[DigitalHubKeys.actionKey]) else {
            return nil
        }

        let otherApp = dictionary[DigitalHubKeys.otherAppKey] as? [String: Any]
        self.init(
            action: action,
            otherAppPath: otherApp?[DigitalHubKeys.cfURLStringKey] as? String
        )
    }

    static func openOtherApplication(at appURL: URL) -> Self {
        DigitalHubDVDAction(
            action: DigitalHubKeys.openOtherApplicationAction,
            otherAppPath: appURL.path
        )
    }

    var dictionaryRepresentation: [String: Any] {
        var dictionary: [String: Any] = [
            DigitalHubKeys.actionKey: action
        ]

        if let otherAppPath {
            dictionary[DigitalHubKeys.otherAppKey] = [
                DigitalHubKeys.cfURLStringKey: otherAppPath,
                DigitalHubKeys.cfURLStringTypeKey: DigitalHubKeys.filePathURLStringType
            ]
        }

        return dictionary
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        default:
            return nil
        }
    }
}

struct DigitalHubDefaultDVDAppPreferenceManager: DefaultDVDAppPreferenceManaging {

    private let appBundleURLProvider: @Sendable () -> URL?
    private let preferenceStore: any DigitalHubPreferenceStoring

    init(
        appBundleURLProvider: @escaping @Sendable () -> URL? = { Bundle.main.bundleURL },
        preferenceStore: any DigitalHubPreferenceStoring = CFPreferencesDigitalHubPreferenceStore()
    ) {
        self.appBundleURLProvider = appBundleURLProvider
        self.preferenceStore = preferenceStore
    }

    func isSwiftRipDefaultDVDApp() -> Bool {
        guard
            let appBundleURL = appBundleURLProvider(),
            let action = currentDVDAction(),
            action.action == DigitalHubKeys.openOtherApplicationAction,
            let configuredPath = action.otherAppPath
        else {
            return false
        }

        return standardizedPath(configuredPath) == standardizedPath(appBundleURL.path)
    }

    func currentDVDAction() -> DigitalHubDVDAction? {
        preferenceStore.dvdAction()
    }

    func makeSwiftRipDefaultDVDApp() throws {
        guard let appBundleURL = appBundleURLProvider() else {
            throw DefaultDVDAppPreferenceError.missingAppBundle
        }

        try preferenceStore.setDVDAction(.openOtherApplication(at: appBundleURL))
    }

    func restoreDVDAction(_ action: DigitalHubDVDAction?) throws {
        try preferenceStore.setDVDAction(action ?? .ignore)
    }

    private func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

protocol DigitalHubPreferenceStoring: Sendable {
    func dvdAction() -> DigitalHubDVDAction?
    func setDVDAction(_ action: DigitalHubDVDAction) throws
}

struct CFPreferencesDigitalHubPreferenceStore: DigitalHubPreferenceStoring {
    private static let domain = DigitalHubKeys.domain as CFString

    func dvdAction() -> DigitalHubDVDAction? {
        guard let dictionary = CFPreferencesCopyAppValue(
            DigitalHubKeys.videoDVDInsertedKey as CFString,
            Self.domain
        ) as? [String: Any] else {
            return nil
        }

        return DigitalHubDVDAction(dictionary: dictionary)
    }

    func setDVDAction(_ action: DigitalHubDVDAction) throws {
        CFPreferencesSetAppValue(
            DigitalHubKeys.videoDVDInsertedKey as CFString,
            action.dictionaryRepresentation as CFDictionary,
            Self.domain
        )

        guard CFPreferencesAppSynchronize(Self.domain) else {
            throw DefaultDVDAppPreferenceError.couldNotSave
        }
    }
}

private enum DigitalHubKeys {
    static let domain = "com.apple.digihub"
    static let videoDVDInsertedKey = "com.apple.digihub.dvd.video.appeared"
    static let actionKey = "action"
    static let otherAppKey = "otherapp"
    static let cfURLStringKey = "_CFURLString"
    static let cfURLStringTypeKey = "_CFURLStringType"
    static let ignoreAction = 1
    static let openOtherApplicationAction = 5
    static let filePathURLStringType = 0
}
