//
//  RipConfiguration.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Foundation

struct RipConfiguration {
    let handBrakeCLIPath: String
    let libdvdcssPath: String
    let presetURL: URL

    static let production = RipConfiguration(
        handBrakeCLIPath: Bundle.main.url(
            forAuxiliaryExecutable: "HandBrakeCLI"
        )?.path ?? "",
        libdvdcssPath: Bundle.main.url(
            forAuxiliaryExecutable: "libdvdcss.2.dylib"
        )?.path ?? "",
        presetURL: Bundle.main.url(
            forResource: "SwiftRip",
            withExtension: "json"
        ) ?? URL(fileURLWithPath: "")
    )

    func handBrakeArguments(input: DVDVolume, outputURL: URL) -> [String] {
        [
            "--preset-import-file", presetURL.path,
            "-Z", "SwiftRip",
            "-i", input.path,
            "-t", "1",
            "-o", outputURL.path
        ]
    }
}
