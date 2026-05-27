//
//  SettingsDraft.swift
//  SwiftRip
//

import Foundation

@MainActor
struct SettingsDraft {
    var outputDirectoryURL: URL
    var isUsingDefaultOutputDirectory: Bool
    var completionSound: CompletionSound
    var isCompletionNotificationEnabled: Bool
    var shouldRevealCompletedFile: Bool
    var shouldAutoEjectAfterSuccessfulRip: Bool
    var outputFilenameFormat: OutputFilenameFormat

    init(settings: AppSettings) {
        self.outputDirectoryURL = settings.outputDirectoryURL
        self.isUsingDefaultOutputDirectory = settings.isUsingDefaultOutputDirectory
        self.completionSound = settings.completionSound
        self.isCompletionNotificationEnabled = settings.isCompletionNotificationEnabled
        self.shouldRevealCompletedFile = settings.shouldRevealCompletedFile
        self.shouldAutoEjectAfterSuccessfulRip = settings.shouldAutoEjectAfterSuccessfulRip
        self.outputFilenameFormat = settings.outputFilenameFormat
    }

    mutating func resetOutputDirectoryToDefault(using fileManager: FileManager = .default) {
        outputDirectoryURL = AppSettings.defaultMoviesDirectory(using: fileManager)
        isUsingDefaultOutputDirectory = true
    }

    mutating func setOutputDirectory(_ url: URL) {
        outputDirectoryURL = url
        isUsingDefaultOutputDirectory = false
    }

    func apply(to settings: AppSettings) throws {
        if isUsingDefaultOutputDirectory {
            settings.resetOutputDirectoryToMovies()
        } else if outputDirectoryURL != settings.outputDirectoryURL || settings.isUsingDefaultOutputDirectory {
            try settings.setOutputDirectory(outputDirectoryURL)
        }

        settings.completionSound = completionSound
        settings.isCompletionNotificationEnabled = isCompletionNotificationEnabled
        settings.shouldRevealCompletedFile = shouldRevealCompletedFile
        settings.shouldAutoEjectAfterSuccessfulRip = shouldAutoEjectAfterSuccessfulRip
        settings.outputFilenameFormat = outputFilenameFormat
    }
}
