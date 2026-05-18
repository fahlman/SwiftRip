//
//  AboutSwiftRipView.swift
//  SwiftRip
//

import AppKit
import SwiftUI

struct AboutSwiftRipView: View {
    private static let appDescription = AppStrings.aboutDescription
    private static let openLicensesFolderTitle = AppStrings.showLicensesTitle
    private static let licenseFileSuffix = "COPYING"

    var body: some View {
        VStack(alignment: .leading, spacing: SwiftRipLayout.AboutWindow.contentSpacing) {
            headerSection
            descriptionSection
            Divider()
            bundledToolsSection
            Divider()
            licensesSection
            Spacer(minLength: 0)
        }
        .padding(SwiftRipLayout.AboutWindow.contentPadding)
        .swiftRipWindowFrame(width: SwiftRipLayout.AboutWindow.width, height: SwiftRipLayout.AboutWindow.height)
        .accessibilityIdentifier("aboutWindow")
    }

    private var headerSection: some View {
        HStack(spacing: SwiftRipLayout.AboutWindow.headerSpacing) {
            Image(systemName: SwiftRipSymbols.selectedOpticalDisc)
                .font(.system(size: SwiftRipLayout.AboutWindow.appIconSize))
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: SwiftRipLayout.AboutWindow.titleSpacing) {
                Text(RipConfiguration.appName)
                    .font(.title2.bold())

                Text(appVersionText)
                    .font(.subheadline)
                    .swiftRipSecondaryText()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aboutHeader")
    }

    private var descriptionSection: some View {
        Text(Self.appDescription)
            .swiftRipSecondaryText()
            .accessibilityIdentifier("aboutDescription")
    }

    private var bundledToolsSection: some View {
        VStack(alignment: .leading, spacing: SwiftRipLayout.AboutWindow.sectionSpacing) {
            Text(AppStrings.bundledToolsTitle)
                .swiftRipSectionTitle()

            Label(RipConfiguration.handBrakeCLIExecutableName, systemImage: SwiftRipSymbols.handBrakeCLI)
            Label(RipConfiguration.libdvdcssLibraryName, systemImage: SwiftRipSymbols.libdvdcss)
        }
    }

    private var licensesSection: some View {
        VStack(alignment: .leading, spacing: SwiftRipLayout.AboutWindow.sectionSpacing) {
            Text(AppStrings.licensesTitle)
                .swiftRipSectionTitle()

            Text(AppStrings.licenseDescription(appName: RipConfiguration.appName))
                .swiftRipSecondaryText()

            licenseList
            showLicensesButton
        }
    }

    private var licenseList: some View {
        Group {
            if licenseNames.isEmpty {
                Text(AppStrings.noLicensesFound)
                    .swiftRipSecondaryText()
            } else {
                ForEach(licenseNames, id: \.self) { name in
                    Label(name, systemImage: SwiftRipSymbols.license)
                }
            }
        }
    }

    private var showLicensesButton: some View {
        Button {
            openLicensesFolder()
        } label: {
            Text(Self.openLicensesFolderTitle)
        }
        .buttonStyle(SwiftRipButtonStyle(prominence: .secondary))
        .disabled(licensesURL == nil)
        .padding(.top, SwiftRipLayout.AboutWindow.buttonTopPadding)
        .accessibilityIdentifier("showLicensesButton")
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

#Preview {
    AboutSwiftRipView()
}
