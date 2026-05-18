//
//  SettingsView.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/18/26.
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: SwiftRipLayout.SettingsWindow.contentSpacing) {
                VStack(spacing: SwiftRipLayout.SettingsWindow.headerSpacing) {
                    Image(systemName: SwiftRipSymbols.folder)
                        .font(.system(size: SwiftRipLayout.SettingsWindow.iconSize))
                        .symbolRenderingMode(.hierarchical)

                    Text(AppStrings.settingsFilesTitle)
                        .swiftRipSectionTitle()
                }

                Divider()

                VStack(alignment: .leading, spacing: SwiftRipLayout.SettingsWindow.rowSpacing) {
                    outputLocationRow
                    outputLocationControls
                    filenameFormatRow

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(SwiftRipColors.errorText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, SwiftRipLayout.SettingsWindow.controlIndent)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: SwiftRipLayout.SettingsWindow.rowSpacing) {
                    Text(AppStrings.settingsCompletionTitle)
                        .swiftRipSectionTitle()

                    completionSoundRow

                    Toggle(AppStrings.settingsNotificationTitle, isOn: $settings.isCompletionNotificationEnabled)
                        .padding(.leading, SwiftRipLayout.SettingsWindow.controlIndent)

                    Toggle(AppStrings.settingsRevealCompletedFileTitle, isOn: $settings.shouldRevealCompletedFile)
                        .padding(.leading, SwiftRipLayout.SettingsWindow.controlIndent)

                    Toggle(AppStrings.settingsAutoEjectTitle, isOn: $settings.shouldAutoEjectAfterSuccessfulRip)
                        .padding(.leading, SwiftRipLayout.SettingsWindow.controlIndent)
                }

                Spacer(minLength: 0)
            }
            .padding(SwiftRipLayout.SettingsWindow.contentPadding)

            Divider()

            HStack {
                Spacer()

                Button {
                    dismissSettingsWindow()
                } label: {
                    Text(AppStrings.settingsCancelTitle)
                        .frame(width: SwiftRipLayout.Button.dialogFooterWidth)
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(SwiftRipButtonStyle(prominence: .secondary))

                Button {
                    dismissSettingsWindow()
                } label: {
                    Text(AppStrings.settingsOKTitle)
                        .frame(width: SwiftRipLayout.Button.dialogFooterWidth)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(SwiftRipButtonStyle(prominence: .primary))
            }
            .swiftRipDialogFooterPadding()
        }
        .swiftRipWindowFrame(width: SwiftRipLayout.SettingsWindow.width, height: SwiftRipLayout.SettingsWindow.height)
    }

    private var outputLocationRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(AppStrings.settingsOutputLocationTitle)
                .swiftRipSettingsLabel()
                .frame(width: SwiftRipLayout.SettingsWindow.labelWidth, alignment: .trailing)

            outputDirectoryBreadcrumb
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var outputLocationControls: some View {
        HStack(spacing: SwiftRipLayout.SettingsWindow.controlSpacing) {
            Spacer()
                .frame(width: SwiftRipLayout.SettingsWindow.controlIndent)

            Button {
                chooseOutputDirectory()
            } label: {
                Text(AppStrings.settingsChangeTitle)
                    .frame(width: SwiftRipLayout.Button.settingsWidth)
            }
            .buttonStyle(SwiftRipButtonStyle(prominence: .secondary))

            Button {
                settings.resetOutputDirectoryToMovies()
                errorMessage = nil
            } label: {
                Text(AppStrings.settingsResetTitle)
                    .frame(width: SwiftRipLayout.Button.settingsWidth)
            }
            .buttonStyle(SwiftRipButtonStyle(prominence: .secondary))
            .disabled(settings.isUsingDefaultOutputDirectory)

            Spacer(minLength: 0)
        }
    }

    private var filenameFormatRow: some View {
        HStack {
            Text(AppStrings.settingsFilenameFormatTitle)
                .swiftRipSettingsLabel()
                .frame(width: SwiftRipLayout.SettingsWindow.labelWidth, alignment: .trailing)

            Picker("", selection: $settings.outputFilenameFormat) {
                ForEach(OutputFilenameFormat.allCases) { format in
                    Text(format.title)
                        .tag(format)
                }
            }
            .labelsHidden()
            .frame(width: 240, alignment: .leading)
        }
    }

    private var completionSoundRow: some View {
        HStack {
            Text(AppStrings.settingsCompletionSoundTitle)
                .swiftRipSettingsLabel()
                .frame(width: SwiftRipLayout.SettingsWindow.labelWidth, alignment: .trailing)

            Picker("", selection: $settings.completionSound) {
                ForEach(CompletionSound.allCases) { sound in
                    Text(sound.title)
                        .tag(sound)
                }
            }
            .labelsHidden()
            .frame(width: 160, alignment: .leading)
        }
    }

    private var outputDirectoryBreadcrumb: some View {
        HStack(spacing: SwiftRipLayout.SettingsWindow.breadcrumbSpacing) {
            ForEach(outputDirectoryBreadcrumbItems.indices, id: \.self) { index in
                if index > 0 {
                    Image(systemName: SwiftRipSymbols.chevronRight)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SwiftRipColors.secondaryText)
                }

                Label {
                    Text(outputDirectoryBreadcrumbItems[index])
                        .foregroundStyle(SwiftRipColors.secondaryText)
                } icon: {
                    Image(systemName: SwiftRipSymbols.folderFill)
                        .foregroundStyle(SwiftRipColors.folderIcon)
                }
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
            }
        }
        .font(.body.weight(.semibold))
        .lineLimit(1)
        .truncationMode(.middle)
        .textSelection(.enabled)
    }

    private var outputDirectoryBreadcrumbItems: [String] {
        if settings.isUsingDefaultOutputDirectory {
            return [NSUserName(), "Movies"]
        }

        let homeURL = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let outputURL = settings.outputDirectoryURL.standardizedFileURL

        if outputURL.path.hasPrefix(homeURL.path) {
            let relativePath = outputURL.path.replacingOccurrences(of: homeURL.path + "/", with: "")
            return [NSUserName()] + relativePath.split(separator: "/").map(String.init)
        }

        return outputURL.pathComponents.filter { $0 != "/" }
    }

    private func dismissSettingsWindow() {
        NSApp.keyWindow?.close()
    }

    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = AppStrings.settingsChangePrompt

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try settings.setOutputDirectory(url)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
}
