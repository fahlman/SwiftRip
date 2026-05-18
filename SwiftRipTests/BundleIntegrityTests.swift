//
//  BundleIntegrityTests.swift
//  SwiftRipTests
//

import Foundation
import Testing
@testable import SwiftRip

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

    @Test func bundledPresetIsReadableJSON() throws {
        let data = try Data(contentsOf: RipConfiguration.production.presetURL)
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        #expect(jsonObject is [String: Any])
    }

    @Test func bundledThirdPartyLicenseNoticesExistAndAreNonEmpty() throws {
        let licenseNames = [
            "HandBrake_COPYING",
            "libdvdcss_COPYING"
        ]

        for licenseName in licenseNames {
            let licenseURL = try #require(Bundle.main.url(forResource: licenseName, withExtension: nil))
            let attributes = try FileManager.default.attributesOfItem(atPath: licenseURL.path)
            let fileSize = try #require(attributes[.size] as? Int)

            #expect(fileSize > 0)
        }
    }
}
