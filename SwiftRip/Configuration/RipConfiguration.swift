//
//  RipConfiguration.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Foundation

struct RipConfiguration {
    static let appName = "SwiftRip"
    static let presetResourceName = "SwiftRip"
    static let presetFileExtension = "json"
    static let handBrakeCLIExecutableName = "HandBrakeCLI"
    static let libdvdcssLibraryName = "libdvdcss.2.dylib"

    let handBrakeCLIPath: String
    let libdvdcssPath: String
    let presetURL: URL

    static let production = RipConfiguration(
        handBrakeCLIPath: Bundle.main.url(
            forAuxiliaryExecutable: handBrakeCLIExecutableName
        )?.path ?? "",
        libdvdcssPath: Bundle.main.url(
            forAuxiliaryExecutable: libdvdcssLibraryName
        )?.path ?? "",
        presetURL: Bundle.main.url(
            forResource: presetResourceName,
            withExtension: presetFileExtension
        ) ?? URL(fileURLWithPath: "")
    )

    func handBrakeArguments(input: DVDVolume, outputURL: URL) -> [String] {
        [
            "--preset-import-file", presetURL.path,
            "-Z", Self.appName,
            "-i", input.path,
            "-t", "1",
            "-o", outputURL.path
        ]
    }
}
