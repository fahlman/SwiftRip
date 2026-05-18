//
//  BundleIntegrityTests.swift
//  SwiftRipTests
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Foundation
import Testing
@testable import SwiftRip

@MainActor
struct BundleIntegrityTests {

    @Test func productionConfigurationReferencesBundledToolsAndPreset() {
        let configuration = RipConfiguration.production

        #expect(configuration.handBrakeCLIPath.hasSuffix("/\(RipConfiguration.handBrakeCLIExecutableName)"))
        #expect(configuration.libdvdcssPath.hasSuffix("/\(RipConfiguration.libdvdcssLibraryName)"))
        #expect(configuration.presetURL.lastPathComponent == "\(RipConfiguration.presetResourceName).\(RipConfiguration.presetFileExtension)")
    }

    @Test func bundledToolsAndPresetExist() {
        let configuration = RipConfiguration.production
        let fileManager = FileManager.default

        #expect(fileManager.isExecutableFile(atPath: configuration.handBrakeCLIPath))
        #expect(fileManager.fileExists(atPath: configuration.libdvdcssPath))
        #expect(fileManager.fileExists(atPath: configuration.presetURL.path))
    }
}
