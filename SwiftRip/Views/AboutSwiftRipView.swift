//
//  AboutSwiftRipView.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/17/26.
//

import AppKit
import SwiftUI

struct AboutSwiftRipView: View {
    private static let appDescription = AppStrings.aboutDescription
    private static let appIconName = "opticaldisc.fill"
    private static let handBrakeCLIIconName = "wineglass.fill"
    private static let libdvdcssIconName = "cone.fill"
    private static let licenseIconName = "doc.text"
    private static let openLicensesFolderTitle = AppStrings.showLicensesTitle
    private static let openLicensesFolderIconName = "folder"
    private static let licenseFileSuffix = "COPYING"

    private enum Layout {
        static let contentSpacing: CGFloat = 18
        static let contentPadding: CGFloat = 24
        static let windowWidth: CGFloat = 520
        static let windowHeight: CGFloat = 420
        static let headerSpacing: CGFloat = 14
        static let titleSpacing: CGFloat = 4
        static let appIconSize: CGFloat = 44
        static let sectionSpacing: CGFloat = 8
        static let buttonTopPadding: CGFloat = 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.contentSpacing) {
            headerSection
            descriptionSection
            Divider()
            bundledToolsSection
            Divider()
            licensesSection
            Spacer(minLength: 0)
        }
        .padding(Layout.contentPadding)
        .frame(width: Layout.windowWidth, height: Layout.windowHeight)
    }

    private var headerSection: some View {
        HStack(spacing: Layout.headerSpacing) {
            Image(systemName: Self.appIconName)
                .font(.system(size: Layout.appIconSize))
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: Layout.titleSpacing) {
                Text(RipConfiguration.appName)
                    .font(.title2.bold())

                Text(appVersionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var descriptionSection: some View {
        Text(Self.appDescription)
            .foregroundStyle(.secondary)
    }

    private var bundledToolsSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            Text(AppStrings.bundledToolsTitle)
                .font(.headline)

            Label(RipConfiguration.handBrakeCLIExecutableName, systemImage: Self.handBrakeCLIIconName)
            Label(RipConfiguration.libdvdcssLibraryName, systemImage: Self.libdvdcssIconName)
        }
    }

    private var licensesSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            Text(AppStrings.licensesTitle)
                .font(.headline)

            Text(AppStrings.licenseDescription(appName: RipConfiguration.appName))
                .foregroundStyle(.secondary)

            licenseList
            showLicensesButton
        }
    }

    private var licenseList: some View {
        Group {
            if licenseNames.isEmpty {
                Text(AppStrings.noLicensesFound)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(licenseNames, id: \.self) { name in
                    Label(name, systemImage: Self.licenseIconName)
                }
            }
        }
    }

    private var showLicensesButton: some View {
        Button {
            openLicensesFolder()
        } label: {
            Label(Self.openLicensesFolderTitle, systemImage: Self.openLicensesFolderIconName)
        }
        .disabled(licensesURL == nil)
        .padding(.top, Layout.buttonTopPadding)
    }

    private var appVersionText: String {
        let infoDictionary = Bundle.main.infoDictionary
        let version = infoDictionary?["CFBundleShortVersionString"] as? String
        let build = infoDictionary?["CFBundleVersion"] as? String

        switch (version, build) {
        case let (.some(version), .some(build)):
            return AppStrings.version(version, build: build)
        case let (.some(version), .none):
            return AppStrings.version(version)
        case let (.none, .some(build)):
            return AppStrings.build(build)
        case (.none, .none):
            return AppStrings.versionUnknown
        }
    }

    private func openLicensesFolder() {
        guard let licensesURL else { return }
        NSWorkspace.shared.open(licensesURL)
    }

    private var licensesURL: URL? {
        guard let firstLicenseURL = licenseURLs.first else { return nil }
        return firstLicenseURL.deletingLastPathComponent()
    }

    private var licenseNames: [String] {
        licenseURLs.map(\.lastPathComponent)
    }

    private var licenseURLs: [URL] {
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
            .filter { $0.lastPathComponent.hasSuffix(Self.licenseFileSuffix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
