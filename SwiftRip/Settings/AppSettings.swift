//
//  AppSettings.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/18/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private static let outputDirectoryBookmarkKey = "outputDirectoryBookmark"

    private(set) var outputDirectoryURL: URL

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
}
