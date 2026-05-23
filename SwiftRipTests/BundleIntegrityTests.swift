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
        #expect(configuration.libdvdcssPath.contains("/Contents/Frameworks/"))
        #expect(configuration.presetURL.lastPathComponent == "\(RipConfiguration.presetResourceName).\(RipConfiguration.presetFileExtension)")
    }

    @Test func bundledToolsAndPresetExist() {
        let configuration = RipConfiguration.production
        let fileManager = FileManager.default
        let legacyMacOSLibdvdcssPath = URL(fileURLWithPath: configuration.handBrakeCLIPath)
            .deletingLastPathComponent()
            .appendingPathComponent(RipConfiguration.libdvdcssLibraryName)
            .path

        #expect(fileManager.isExecutableFile(atPath: configuration.handBrakeCLIPath))
        #expect(fileManager.fileExists(atPath: configuration.libdvdcssPath))
        #expect(!fileManager.fileExists(atPath: legacyMacOSLibdvdcssPath))
        #expect(fileManager.fileExists(atPath: configuration.presetURL.path))
    }

    @Test func bundledHandBrakeLoadsLibdvdcssFromFrameworks() throws {
        let handBrakeCLIData = try Data(contentsOf: URL(fileURLWithPath: RipConfiguration.production.handBrakeCLIPath))
        let binaryText = String(decoding: handBrakeCLIData, as: UTF8.self)

        #expect(binaryText.contains("@executable_path/../Frameworks/libdvdcss.2.dylib"))
        #expect(!binaryText.contains("/usr/local/lib/libdvdcss.2.dylib"))
    }

    @Test func bundledPresetIsReadableJSON() throws {
        let data = try Data(contentsOf: RipConfiguration.production.presetURL)
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        #expect(jsonObject is [String: Any])
    }

    @Test func bundledPresetTargetsAppleDevices() throws {
        let preset = try bundledPreset()

        #expect(preset["PresetName"] as? String == "SwiftRip")
        #expect(preset["FileFormat"] as? String == "av_mp4")
        #expect(preset["Optimize"] as? Bool == true)
        #expect(preset["VideoEncoder"] as? String == "vt_h265")
        #expect(preset["VideoQualitySlider"] as? Int == 60)
        #expect(preset["VideoColorRange"] as? String == "limited")
        #expect(preset["SubtitleAddForeignAudioSearch"] as? Bool == true)
        #expect(preset["SubtitleBurnBehavior"] as? String == "foreign")

        let audioList = try #require(preset["AudioList"] as? [[String: Any]])
        #expect(audioList.count == 2)
        #expect(audioList.first?["AudioEncoder"] as? String == "ca_aac")
        #expect(audioList.first?["AudioMixdown"] as? String == "stereo")
        #expect(audioList.first?["AudioBitrate"] as? Int == 192)
        #expect(audioList.last?["AudioEncoder"] as? String == "copy:ac3")
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

    private func bundledPreset() throws -> [String: Any] {
        let data = try Data(contentsOf: RipConfiguration.production.presetURL)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let json = try #require(jsonObject as? [String: Any])
        let presetList = try #require(json["PresetList"] as? [[String: Any]])
        let rootPreset = try #require(presetList.first)
        let children = try #require(rootPreset["ChildrenArray"] as? [[String: Any]])

        return try #require(children.first)
    }
}
