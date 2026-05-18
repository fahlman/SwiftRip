//
//  RipPreflightCheck.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Foundation

struct RipPreflightCheck {
    let configuration: RipConfiguration
    let fileManager: FileManager

    func failureMessage() -> String? {
        if !fileManager.isExecutableFile(atPath: configuration.handBrakeCLIPath) {
            return "\(RipConfiguration.handBrakeCLIExecutableName) was not found at \(configuration.handBrakeCLIPath)."
        }

        if !fileManager.fileExists(atPath: configuration.libdvdcssPath) {
            return "\(RipConfiguration.libdvdcssLibraryName) was not found at \(configuration.libdvdcssPath)."
        }

        if !fileManager.fileExists(atPath: configuration.presetURL.path) {
            return "\(RipConfiguration.appName) preset was not found at \(configuration.presetURL.path)."
        }

        return nil
    }
}
