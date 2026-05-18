//
//  AppSettings.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/18/26.
//

import Foundation
import Observation

enum CompletionSound: String, CaseIterable, Identifiable, Sendable {
    case glass
    case ping
    case hero
    case none

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .glass:
            return AppStrings.completionSoundGlassTitle
        case .ping:
            return AppStrings.completionSoundPingTitle
        case .hero:
            return AppStrings.completionSoundHeroTitle
        case .none:
            return AppStrings.completionSoundNoneTitle
        }
    }

    var soundName: String? {
        switch self {
        case .glass:
            return "Glass"
        case .ping:
            return "Ping"
        case .hero:
            return "Hero"
        case .none:
            return nil
        }
    }
}

enum OutputFilenameFormat: String, CaseIterable, Identifiable, Sendable {
    case titleCase
    case originalName
    case datedTitleCase

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .titleCase:
            return AppStrings.filenameFormatTitleCaseTitle
        case .originalName:
            return AppStrings.filenameFormatOriginalNameTitle
        case .datedTitleCase:
            return AppStrings.filenameFormatDatedTitleCaseTitle
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private static let outputDirectoryBookmarkKey = "outputDirectoryBookmark"
    private static let completionSoundKey = "completionSound"
    private static let completionNotificationEnabledKey = "completionNotificationEnabled"
    private static let revealCompletedFileKey = "revealCompletedFile"
    private static let outputFilenameFormatKey = "outputFilenameFormat"

    private(set) var outputDirectoryURL: URL
    var completionSound: CompletionSound {
        didSet {
            userDefaults.set(completionSound.rawValue, forKey: Self.completionSoundKey)
        }
    }
    var isCompletionNotificationEnabled: Bool {
        didSet {
            userDefaults.set(isCompletionNotificationEnabled, forKey: Self.completionNotificationEnabledKey)
        }
    }
    var shouldRevealCompletedFile: Bool {
        didSet {
            userDefaults.set(shouldRevealCompletedFile, forKey: Self.revealCompletedFileKey)
        }
    }
    var outputFilenameFormat: OutputFilenameFormat {
        didSet {
            userDefaults.set(outputFilenameFormat.rawValue, forKey: Self.outputFilenameFormatKey)
        }
    }

    @ObservationIgnored
    private let userDefaults: UserDefaults
    @ObservationIgnored
    private let fileManager: FileManager
    @ObservationIgnored
    private var securityScopedOutputDirectoryURL: URL?

    convenience init() {
        self.init(userDefaults: .standard, fileManager: .default)
    }

    init(userDefaults: UserDefaults, fileManager: FileManager) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        self.outputDirectoryURL = Self.moviesDirectory(using: fileManager)
        self.completionSound = Self.completionSound(from: userDefaults)
        self.isCompletionNotificationEnabled = Self.boolValue(
            forKey: Self.completionNotificationEnabledKey,
            defaultValue: true,
            in: userDefaults
        )
        self.shouldRevealCompletedFile = Self.boolValue(
            forKey: Self.revealCompletedFileKey,
            defaultValue: true,
            in: userDefaults
        )
        self.outputFilenameFormat = Self.outputFilenameFormat(from: userDefaults)
        self.outputDirectoryURL = resolvedOutputDirectoryURL()
    }

    var isUsingDefaultOutputDirectory: Bool {
        userDefaults.data(forKey: Self.outputDirectoryBookmarkKey) == nil
    }

    func setOutputDirectory(_ url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        stopAccessingSecurityScopedOutputDirectory()
        userDefaults.set(bookmarkData, forKey: Self.outputDirectoryBookmarkKey)
        outputDirectoryURL = resolvedOutputDirectoryURL()
    }

    func resetOutputDirectoryToMovies() {
        stopAccessingSecurityScopedOutputDirectory()
        userDefaults.removeObject(forKey: Self.outputDirectoryBookmarkKey)
        outputDirectoryURL = Self.moviesDirectory(using: fileManager)
    }

    private func resolvedOutputDirectoryURL() -> URL {
        guard let bookmarkData = userDefaults.data(forKey: Self.outputDirectoryBookmarkKey) else {
            return Self.moviesDirectory(using: fileManager)
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard url.startAccessingSecurityScopedResource() else {
                resetOutputDirectoryToMovies()
                return Self.moviesDirectory(using: fileManager)
            }

            securityScopedOutputDirectoryURL = url

            if isStale {
                try setOutputDirectory(url)
            }

            return url
        } catch {
            resetOutputDirectoryToMovies()
            return Self.moviesDirectory(using: fileManager)
        }
    }

    private func stopAccessingSecurityScopedOutputDirectory() {
        securityScopedOutputDirectoryURL?.stopAccessingSecurityScopedResource()
        securityScopedOutputDirectoryURL = nil
    }

    private static func moviesDirectory(using fileManager: FileManager) -> URL {
        fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Movies", isDirectory: true)
    }

    private static func completionSound(from userDefaults: UserDefaults) -> CompletionSound {
        guard let rawValue = userDefaults.string(forKey: completionSoundKey) else { return .glass }
        return CompletionSound(rawValue: rawValue) ?? .glass
    }

    private static func outputFilenameFormat(from userDefaults: UserDefaults) -> OutputFilenameFormat {
        guard let rawValue = userDefaults.string(forKey: outputFilenameFormatKey) else { return .titleCase }
        return OutputFilenameFormat(rawValue: rawValue) ?? .titleCase
    }

    private static func boolValue(forKey key: String, defaultValue: Bool, in userDefaults: UserDefaults) -> Bool {
        userDefaults.object(forKey: key) as? Bool ?? defaultValue
    }
}
