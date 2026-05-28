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
    static let currentUsageNoticeVersion = 1

    private static let userDefaultsSuiteEnvironmentKey = "SWIFTRIP_APP_SETTINGS_SUITE"

    private(set) var outputDirectoryURL: URL
    var completionSound: CompletionSound {
        get { preferences.completionSound }
        set { updatePreferences { $0.completionSound = newValue } }
    }
    var isCompletionNotificationEnabled: Bool {
        get { preferences.isCompletionNotificationEnabled }
        set { updatePreferences { $0.isCompletionNotificationEnabled = newValue } }
    }
    var shouldRevealCompletedFile: Bool {
        get { preferences.shouldRevealCompletedFile }
        set { updatePreferences { $0.shouldRevealCompletedFile = newValue } }
    }
    var shouldAutoEjectAfterSuccessfulRip: Bool {
        get { preferences.shouldAutoEjectAfterSuccessfulRip }
        set { updatePreferences { $0.shouldAutoEjectAfterSuccessfulRip = newValue } }
    }
    var outputFilenameFormat: OutputFilenameFormat {
        get { preferences.outputFilenameFormat }
        set { updatePreferences { $0.outputFilenameFormat = newValue } }
    }
    var hasAcknowledgedCurrentUsageNotice: Bool {
        preferences.usageNoticeAcknowledgedVersion >= Self.currentUsageNoticeVersion
    }

    @ObservationIgnored
    private let preferencesStore: UserPreferencesStoring
    @ObservationIgnored
    private let outputDirectoryBookmarkStore: OutputDirectoryBookmarkStore
    private var preferences: UserPreferences

    convenience init() {
        if
            let suiteName = AppLaunchConfiguration.value(for: Self.userDefaultsSuiteEnvironmentKey),
            let userDefaults = UserDefaults(suiteName: suiteName) {
            self.init(userDefaults: userDefaults, fileManager: .default)
            return
        }

        self.init(userDefaults: .standard, fileManager: .default)
    }

    init(
        userDefaults: UserDefaults,
        fileManager: FileManager
    ) {
        self.preferencesStore = UserDefaultsUserPreferencesStore(userDefaults: userDefaults)
        self.outputDirectoryBookmarkStore = OutputDirectoryBookmarkStore(
            userDefaults: userDefaults,
            fileManager: fileManager
        )
        self.outputDirectoryURL = Self.defaultMoviesDirectory(using: fileManager)
        self.preferences = preferencesStore.load()
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

    func startAccessingOutputDirectory() -> (any SecurityScopedResourceAccess)? {
        outputDirectoryBookmarkStore.startAccessingResolvedOutputDirectory()
    }

    func acknowledgeCurrentUsageNotice() {
        updatePreferences { $0.usageNoticeAcknowledgedVersion = Self.currentUsageNoticeVersion }
    }

    static func defaultMoviesDirectory(using fileManager: FileManager) -> URL {
        OutputDirectoryBookmarkStore.defaultMoviesDirectory(using: fileManager)
    }

    private func updatePreferences(_ update: (inout UserPreferences) -> Void) {
        update(&preferences)
        preferencesStore.save(preferences)
    }
}
