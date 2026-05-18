//
//  AboutSwiftRipView.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/17/26.
//

import AppKit
import SwiftUI

struct AboutSwiftRipView: View {
    private static let appDescription = "A small macOS DVD ripping tool built around bundled ARM64 ripping tools."
    private static let appIconName = "opticaldisc.fill"
    private static let handBrakeCLIIconName = "wineglass.fill"
    private static let libdvdcssIconName = "cone.fill"
    private static let licenseIconName = "doc.text"
    private static let openLicensesFolderTitle = "Show Licenses"
    private static let openLicensesFolderIconName = "folder"
    private static let licenseFileSuffix = "COPYING"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: Self.appIconName)
                    .font(.system(size: 44))
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 4) {
                    Text(RipConfiguration.appName)
                        .font(.title2.bold())

                    Text(appVersionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(Self.appDescription)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Bundled Tools")
                    .font(.headline)

                Label(RipConfiguration.handBrakeCLIExecutableName, systemImage: Self.handBrakeCLIIconName)
                Label(RipConfiguration.libdvdcssLibraryName, systemImage: Self.libdvdcssIconName)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Licenses")
                    .font(.headline)

                Text("\(RipConfiguration.appName) includes bundled third-party tools. Their license files are included in the app bundle resources.")
                    .foregroundStyle(.secondary)

                if licenseNames.isEmpty {
                    Text("No bundled license files were found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(licenseNames, id: \.self) { name in
                        Label(name, systemImage: Self.licenseIconName)
                    }
                }

                Button {
                    openLicensesFolder()
                } label: {
                    Label(Self.openLicensesFolderTitle, systemImage: Self.openLicensesFolderIconName)
                }
                .disabled(licensesURL == nil)
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 520, height: 420)
    }

    private var appVersionText: String {
        let infoDictionary = Bundle.main.infoDictionary
        let version = infoDictionary?["CFBundleShortVersionString"] as? String
        let build = infoDictionary?["CFBundleVersion"] as? String

        switch (version, build) {
        case let (.some(version), .some(build)):
            return "Version \(version) (\(build))"
        case let (.some(version), .none):
            return "Version \(version)"
        case let (.none, .some(build)):
            return "Build \(build)"
        case (.none, .none):
            return "Version unknown"
        }
    }

    private func openLicensesFolder() {
        guard let licensesURL else { return }

        NSWorkspace.shared.selectFile(
            licensesURL.path,
            inFileViewerRootedAtPath: licensesURL.deletingLastPathComponent().path
        )
    }

    private var licensesURL: URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        return licenseNames.isEmpty ? nil : resourceURL
    }

    private var licenseNames: [String] {
        guard let resourceURL = Bundle.main.resourceURL,
              let urls = try? FileManager.default.contentsOfDirectory(
                at: resourceURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return urls
            .filter { !$0.hasDirectoryPath }
            .map { $0.lastPathComponent }
            .filter { $0.hasSuffix(Self.licenseFileSuffix) }
            .sorted()
    }
}
