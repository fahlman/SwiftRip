//
//  DVDVolumeFinder.swift
//  SwiftRip
//

import AppKit
import Foundation

protocol DVDDeviceEjecting: Sendable {
    @MainActor func ejectDVD(at url: URL) throws
}

struct WorkspaceDVDDeviceEjector: DVDDeviceEjecting {
    func ejectDVD(at url: URL) throws {
        try NSWorkspace.shared.unmountAndEjectDevice(at: url)
    }
}

protocol DVDVolumeFinding: Sendable {
    func findMountedDVDs() -> [DVDVolume]
}

struct FileSystemDVDVolumeFinder: DVDVolumeFinding {
    private let fileManager: FileManager
    private let volumesURL: URL

    init(
        fileManager: FileManager = .default,
        volumesURL: URL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
    ) {
        self.fileManager = fileManager
        self.volumesURL = volumesURL
    }

    func findMountedDVDs() -> [DVDVolume] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { url in
                let videoTS = url.appendingPathComponent(DVDVolume.videoTSDirectoryName, isDirectory: true)
                return fileManager.fileExists(atPath: videoTS.path)
            }
            .map { url in
                DVDVolume(id: url.path, name: url.lastPathComponent, path: url.path)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
