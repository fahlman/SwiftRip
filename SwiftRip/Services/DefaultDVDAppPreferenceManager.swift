//
//  DefaultDVDAppPreferenceManager.swift
//  SwiftRip
//

import Foundation

protocol DefaultDVDAppPreferenceManaging: Sendable {
    func isSwiftRipDefaultDVDApp() -> Bool
    func setSwiftRipAsDefaultDVDApp(_ isEnabled: Bool) throws
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

struct DigitalHubDefaultDVDAppPreferenceManager: DefaultDVDAppPreferenceManaging {
    private static let videoDVDInsertedKey = "com.apple.digihub.dvd.video.appeared"
    private static let actionKey = "action"
    private static let otherAppKey = "otherapp"
    private static let cfURLStringKey = "_CFURLString"
    private static let cfURLStringTypeKey = "_CFURLStringType"
    private static let ignoreAction = 1
    private static let openOtherApplicationAction = 5
    private static let filePathURLStringType = 0

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
            let preference = preferenceStore.dictionary(forKey: Self.videoDVDInsertedKey),
            intValue(preference[Self.actionKey]) == Self.openOtherApplicationAction,
            let otherApp = preference[Self.otherAppKey] as? [String: Any],
            let configuredPath = otherApp[Self.cfURLStringKey] as? String
        else {
            return false
        }

        return standardizedPath(configuredPath) == standardizedPath(appBundleURL.path)
    }

    func setSwiftRipAsDefaultDVDApp(_ isEnabled: Bool) throws {
        guard let appBundleURL = appBundleURLProvider() else {
            throw DefaultDVDAppPreferenceError.missingAppBundle
        }

        if isEnabled {
            try preferenceStore.setDictionary(
                [
                    Self.actionKey: Self.openOtherApplicationAction,
                    Self.otherAppKey: [
                        Self.cfURLStringKey: appBundleURL.path,
                        Self.cfURLStringTypeKey: Self.filePathURLStringType
                    ]
                ],
                forKey: Self.videoDVDInsertedKey
            )
            return
        }

        guard isSwiftRipDefaultDVDApp() else { return }

        try preferenceStore.setDictionary(
            [Self.actionKey: Self.ignoreAction],
            forKey: Self.videoDVDInsertedKey
        )
    }

    private func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        default:
            return nil
        }
    }

    private func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

protocol DigitalHubPreferenceStoring: Sendable {
    func dictionary(forKey key: String) -> [String: Any]?
    func setDictionary(_ dictionary: [String: Any], forKey key: String) throws
}

struct CFPreferencesDigitalHubPreferenceStore: DigitalHubPreferenceStoring {
    private static let domain = "com.apple.digihub" as CFString

    func dictionary(forKey key: String) -> [String: Any]? {
        CFPreferencesCopyAppValue(key as CFString, Self.domain) as? [String: Any]
    }

    func setDictionary(_ dictionary: [String: Any], forKey key: String) throws {
        CFPreferencesSetAppValue(key as CFString, dictionary as CFDictionary, Self.domain)

        guard CFPreferencesAppSynchronize(Self.domain) else {
            throw DefaultDVDAppPreferenceError.couldNotSave
        }
    }
}
