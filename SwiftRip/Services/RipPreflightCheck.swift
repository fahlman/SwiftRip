//
//  RipPreflightCheck.swift
//  SwiftRip
//

import Foundation

struct RipPreflightCheck {
    let configuration: RipConfiguration
    let fileManager: FileManager

    func failureMessage(outputURL: URL? = nil) -> String? {
        if let outputURL, let outputDirectoryFailure = outputDirectoryFailureMessage(for: outputURL) {
            return outputDirectoryFailure
        }

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

    private func outputDirectoryFailureMessage(for outputURL: URL) -> String? {
        let directoryURL = outputURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) else {
            return AppStrings.outputDirectoryMissing
        }

        guard isDirectory.boolValue else {
            return AppStrings.outputDirectoryNotFolder
        }

        let probeURL = directoryURL.appendingPathComponent(".swiftrip-write-test-\(UUID().uuidString)")

        do {
            try Data().write(to: probeURL, options: .withoutOverwriting)
            try fileManager.removeItem(at: probeURL)
            return nil
        } catch {
            try? fileManager.removeItem(at: probeURL)
            return AppStrings.outputDirectoryNotWritable(directoryURL.path, errorDescription: error.localizedDescription)
        }
    }
}
