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
            return AppStrings.missingHandBrakeCLI(path: configuration.handBrakeCLIPath)
        }

        if !fileManager.fileExists(atPath: configuration.libdvdcssPath) {
            return AppStrings.missingLibdvdcss(path: configuration.libdvdcssPath)
        }

        if !fileManager.fileExists(atPath: configuration.presetURL.path) {
            return AppStrings.missingPreset(appName: RipConfiguration.appName, path: configuration.presetURL.path)
        }

        return nil
    }
}
