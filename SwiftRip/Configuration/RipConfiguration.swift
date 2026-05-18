//
//  RipConfiguration.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Foundation

struct RipConfiguration: Sendable {
    nonisolated static let appName = "SwiftRip"
    nonisolated static let presetResourceName = "SwiftRip"
    nonisolated static let presetFileExtension = "json"
    nonisolated static let handBrakeCLIExecutableName = "HandBrakeCLI"
    nonisolated static let libdvdcssLibraryName = "libdvdcss.2.dylib"
    private nonisolated static let missingBundledResourceDirectory = "/missing-bundled-resource"

    nonisolated let handBrakeCLIPath: String
    nonisolated let libdvdcssPath: String
    nonisolated let presetURL: URL

    nonisolated static let production = RipConfiguration(
        handBrakeCLIPath: bundledAuxiliaryExecutablePath(
            named: handBrakeCLIExecutableName
        ),
        libdvdcssPath: bundledAuxiliaryExecutablePath(
            named: libdvdcssLibraryName
        ),
        presetURL: bundledResourceURL(
            named: presetResourceName,
            extension: presetFileExtension
        )
    )

    private nonisolated static func bundledAuxiliaryExecutablePath(named name: String) -> String {
        Bundle.main.url(forAuxiliaryExecutable: name)?.path
            ?? missingBundledResourceURL(named: name).path
    }

    private nonisolated static func bundledResourceURL(named name: String, extension fileExtension: String) -> URL {
        Bundle.main.url(forResource: name, withExtension: fileExtension)
            ?? missingBundledResourceURL(named: "\(name).\(fileExtension)")
    }

    private nonisolated static func missingBundledResourceURL(named name: String) -> URL {
        URL(fileURLWithPath: missingBundledResourceDirectory, isDirectory: true)
            .appendingPathComponent(name)
    }

    nonisolated func handBrakeArguments(input: DVDVolume, outputURL: URL) -> [String] {
        [
            "--preset-import-file", presetURL.path,
            "-Z", Self.appName,
            "-i", input.path,
            "-t", "1",
            "-o", outputURL.path
        ]
    }
}
