//
//  DVDVolume.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Foundation

struct DVDVolume: Identifiable, Hashable {
    static let videoTSDirectoryName = "VIDEO_TS"

    let id: String
    let name: String
    let path: String
}
