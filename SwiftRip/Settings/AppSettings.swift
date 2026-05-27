//
//  AppSettings.swift
//  SwiftRip
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

struct OutputFilenameFormatter: Sendable {
    private static let movieFileExtension = "m4v"
    private static let datedFilenameDateFormat = "yyyy-MM-dd"

    private let dateProvider: @Sendable () -> Date

    init(dateProvider: @escaping @Sendable () -> Date = Date.init) {
        self.dateProvider = dateProvider
    }

    func outputName(for dvdName: String, format: OutputFilenameFormat) -> String {
        let baseName: String
        switch format {
        case .titleCase:
            baseName = titleCasedDVDName(dvdName)
        case .originalName:
            baseName = dvdName
        case .datedTitleCase:
            baseName = "\(titleCasedDVDName(dvdName)) - \(Self.filenameDateFormatter.string(from: dateProvider()))"
        }

        return "\(baseName).\(Self.movieFileExtension)"
    }

    private func titleCasedDVDName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static var filenameDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = datedFilenameDateFormat
        return formatter
    }
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private static let completionSoundKey = "completionSound"
    private static let completionNotificationEnabledKey = "completionNotificationEnabled"
    private static let revealCompletedFileKey = "revealCompletedFile"
    private static let autoEjectAfterSuccessfulRipKey = "autoEjectAfterSuccessfulRip"
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
    var shouldAutoEjectAfterSuccessfulRip: Bool {
        didSet {
            userDefaults.set(shouldAutoEjectAfterSuccessfulRip, forKey: Self.autoEjectAfterSuccessfulRipKey)
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
    private let outputDirectoryBookmarkStore: OutputDirectoryBookmarkStore

    convenience init() {
        self.init(userDefaults: .standard, fileManager: .default)
    }

    init(
        userDefaults: UserDefaults,
        fileManager: FileManager
    ) {
        self.userDefaults = userDefaults
        self.outputDirectoryBookmarkStore = OutputDirectoryBookmarkStore(
            userDefaults: userDefaults,
            fileManager: fileManager
        )
        self.outputDirectoryURL = Self.defaultMoviesDirectory(using: fileManager)
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
        self.shouldAutoEjectAfterSuccessfulRip = Self.boolValue(
            forKey: Self.autoEjectAfterSuccessfulRipKey,
            defaultValue: false,
            in: userDefaults
        )
        self.outputFilenameFormat = Self.outputFilenameFormat(from: userDefaults)
        self.outputDirectoryURL = outputDirectoryBookmarkStore.resolvedOutputDirectoryURL()
    }

    var isUsingDefaultOutputDirectory: Bool {
        outputDirectoryBookmarkStore.isUsingDefaultOutputDirectory
    }

    var needsOutputDirectoryPermission: Bool {
        isUsingDefaultOutputDirectory
    }

    func setOutputDirectory(_ url: URL) throws {
        outputDirectoryURL = try outputDirectoryBookmarkStore.setOutputDirectory(url)
    }

    func resetOutputDirectoryToMovies() {
        outputDirectoryURL = outputDirectoryBookmarkStore.resetOutputDirectoryToDefault()
    }

    static func defaultMoviesDirectory(using fileManager: FileManager) -> URL {
        OutputDirectoryBookmarkStore.defaultMoviesDirectory(using: fileManager)
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
