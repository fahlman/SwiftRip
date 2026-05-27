//
//  OutputDirectoryBookmarkStore.swift
//  SwiftRip
//

import Darwin
import Foundation

@MainActor
final class OutputDirectoryBookmarkStore {
    private static let bookmarkKey = "outputDirectoryBookmark"

    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let accessProvider: any SecurityScopedResourceAccessProviding

    init(
        userDefaults: UserDefaults,
        fileManager: FileManager,
        accessProvider: any SecurityScopedResourceAccessProviding = DefaultSecurityScopedResourceAccessProvider()
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        self.accessProvider = accessProvider
    }

    var isUsingDefaultOutputDirectory: Bool {
        userDefaults.data(forKey: Self.bookmarkKey) == nil
    }

    func setOutputDirectory(_ url: URL) throws -> URL {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        userDefaults.set(bookmarkData, forKey: Self.bookmarkKey)
        return resolvedOutputDirectoryURL()
    }

    func resetOutputDirectoryToDefault() -> URL {
        userDefaults.removeObject(forKey: Self.bookmarkKey)
        return defaultOutputDirectory()
    }

    func resolvedOutputDirectoryURL() -> URL {
        guard let bookmarkData = userDefaults.data(forKey: Self.bookmarkKey) else {
            return defaultOutputDirectory()
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                return try setOutputDirectory(url)
            }

            return url
        } catch {
            return resetOutputDirectoryToDefault()
        }
    }

    func defaultOutputDirectory() -> URL {
        Self.defaultMoviesDirectory(using: fileManager)
    }

    func startAccessingResolvedOutputDirectory() -> (any SecurityScopedResourceAccess)? {
        guard let bookmarkData = userDefaults.data(forKey: Self.bookmarkKey) else {
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            let access = accessProvider.startAccessing(url)
            guard access.isAccessing else {
                _ = resetOutputDirectoryToDefault()
                return nil
            }

            if isStale {
                _ = try setOutputDirectory(url)
            }

            return access
        } catch {
            _ = resetOutputDirectoryToDefault()
            return nil
        }
    }

    static func defaultMoviesDirectory(using fileManager: FileManager) -> URL {
        accountHomeDirectory(using: fileManager).appendingPathComponent("Movies", isDirectory: true)
    }

    private static func accountHomeDirectory(using fileManager: FileManager) -> URL {
        guard
            let passwordEntry = getpwuid(getuid()),
            let homeDirectory = passwordEntry.pointee.pw_dir
        else {
            return fileManager.homeDirectoryForCurrentUser
        }

        return URL(fileURLWithPath: String(cString: homeDirectory), isDirectory: true)
    }
}
