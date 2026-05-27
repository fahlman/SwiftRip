//
//  UserPreferences.swift
//  SwiftRip
//

import Foundation

struct UserPreferences: Equatable, Sendable {
    var completionSound: CompletionSound = .glass
    var isCompletionNotificationEnabled = true
    var shouldRevealCompletedFile = true
    var shouldAutoEjectAfterSuccessfulRip = false
    var outputFilenameFormat: OutputFilenameFormat = .titleCase
}

protocol UserPreferencesStoring {
    func load() -> UserPreferences
    func save(_ preferences: UserPreferences)
}

struct UserDefaultsUserPreferencesStore: UserPreferencesStoring {
    private static let completionSoundKey = "completionSound"
    private static let completionNotificationEnabledKey = "completionNotificationEnabled"
    private static let revealCompletedFileKey = "revealCompletedFile"
    private static let autoEjectAfterSuccessfulRipKey = "autoEjectAfterSuccessfulRip"
    private static let outputFilenameFormatKey = "outputFilenameFormat"

    let userDefaults: UserDefaults

    func load() -> UserPreferences {
        UserPreferences(
            completionSound: completionSound(from: userDefaults),
            isCompletionNotificationEnabled: boolValue(
                forKey: Self.completionNotificationEnabledKey,
                defaultValue: true
            ),
            shouldRevealCompletedFile: boolValue(
                forKey: Self.revealCompletedFileKey,
                defaultValue: true
            ),
            shouldAutoEjectAfterSuccessfulRip: boolValue(
                forKey: Self.autoEjectAfterSuccessfulRipKey,
                defaultValue: false
            ),
            outputFilenameFormat: outputFilenameFormat(from: userDefaults)
        )
    }

    func save(_ preferences: UserPreferences) {
        userDefaults.set(preferences.completionSound.rawValue, forKey: Self.completionSoundKey)
        userDefaults.set(preferences.isCompletionNotificationEnabled, forKey: Self.completionNotificationEnabledKey)
        userDefaults.set(preferences.shouldRevealCompletedFile, forKey: Self.revealCompletedFileKey)
        userDefaults.set(preferences.shouldAutoEjectAfterSuccessfulRip, forKey: Self.autoEjectAfterSuccessfulRipKey)
        userDefaults.set(preferences.outputFilenameFormat.rawValue, forKey: Self.outputFilenameFormatKey)
    }

    private func completionSound(from userDefaults: UserDefaults) -> CompletionSound {
        guard let rawValue = userDefaults.string(forKey: Self.completionSoundKey) else { return .glass }
        return CompletionSound(rawValue: rawValue) ?? .glass
    }

    private func outputFilenameFormat(from userDefaults: UserDefaults) -> OutputFilenameFormat {
        guard let rawValue = userDefaults.string(forKey: Self.outputFilenameFormatKey) else { return .titleCase }
        return OutputFilenameFormat(rawValue: rawValue) ?? .titleCase
    }

    private func boolValue(forKey key: String, defaultValue: Bool) -> Bool {
        userDefaults.object(forKey: key) as? Bool ?? defaultValue
    }
}
