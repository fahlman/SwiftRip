//
//  DVDVolume.swift
//  SwiftRip
//

import Foundation

struct DVDVolume: Identifiable, Hashable, Sendable {
    nonisolated static let videoTSDirectoryName = "VIDEO_TS"

    nonisolated let id: String
    nonisolated let name: String
    nonisolated let url: URL

    nonisolated var path: String {
        url.path
    }

    nonisolated init(id: String, name: String, path: String) {
        self.init(id: id, name: name, url: URL(fileURLWithPath: path, isDirectory: true))
    }

    nonisolated init(id: String? = nil, name: String? = nil, url: URL) {
        self.url = url
        self.id = id ?? url.path
        self.name = name ?? url.lastPathComponent
    }
}
