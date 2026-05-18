//
//  DVDVolume.swift
//  SwiftRip
//

import Foundation

struct DVDVolume: Identifiable, Hashable, Sendable {
    nonisolated static let videoTSDirectoryName = "VIDEO_TS"

    let id: String
    let name: String
    let path: String
}
