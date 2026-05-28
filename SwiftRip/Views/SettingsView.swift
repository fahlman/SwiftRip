//
//  SettingsView.swift
//  SwiftRip
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var draft = SettingsDraft(settings: AppSettings.shared)
    @State private var outputDirectoryErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: SwiftRipLayout.SettingsWindow.contentSpacing) {
                settingsHeader
                Divider()
                filesSection
                Divider()
                completionSection
                Spacer(minLength: 0)
            }
            .padding(SwiftRipLayout.SettingsWindow.contentPadding)

            Divider()
            footer
        }
        .swiftRipWindowFrame(width: SwiftRipLayout.SettingsWindow.width, height: SwiftRipLayout.SettingsWindow.height)
        .accessibilityIdentifier("settingsWindow")
    }

    private var settingsHeader: some View {
        VStack(spacing: SwiftRipLayout.SettingsWindow.headerSpacing) {
            Image(systemName: SwiftRipSymbols.folder)
                .font(.system(size: SwiftRipLayout.SettingsWindow.iconSize))
                .symbolRenderingMode(.hierarchical)

            Text(AppStrings.settingsFilesTitle)
                .swiftRipSectionTitle()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settingsHeader")
    }

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: SwiftRipLayout.SettingsWindow.rowSpacing) {
            outputLocationRow
            outputLocationControls
            filenameFormatRow

            if let outputDirectoryErrorMessage {
                Text(outputDirectoryErrorMessage)
                    .foregroundStyle(SwiftRipColors.errorText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, SwiftRipLayout.SettingsWindow.controlIndent)
                    .accessibilityIdentifier("outputDirectoryErrorMessage")
            }
        }
    }

    private var completionSection: some View {
        VStack(alignment: .leading, spacing: SwiftRipLayout.SettingsWindow.rowSpacing) {
            Text(AppStrings.settingsCompletionTitle)
                .swiftRipSectionTitle()

            completionSoundRow

            Toggle(AppStrings.settingsNotificationTitle, isOn: $draft.isCompletionNotificationEnabled)
                .padding(.leading, SwiftRipLayout.SettingsWindow.controlIndent)
                .accessibilityIdentifier("completionNotificationToggle")

            Toggle(AppStrings.settingsRevealCompletedFileTitle, isOn: $draft.shouldRevealCompletedFile)
                .padding(.leading, SwiftRipLayout.SettingsWindow.controlIndent)
                .accessibilityIdentifier("revealCompletedFileToggle")

            Toggle(AppStrings.settingsAutoEjectTitle, isOn: $draft.shouldAutoEjectAfterSuccessfulRip)
                .padding(.leading, SwiftRipLayout.SettingsWindow.controlIndent)
                .accessibilityIdentifier("autoEjectToggle")
        }
    }

    private var footer: some View {
        HStack {
            Spacer()

            Button {
                cancelSettings()
            } label: {
                Text(AppStrings.settingsCancelTitle)
                    .frame(width: SwiftRipLayout.Button.dialogFooterWidth)
                    .accessibilityIdentifier("settingsCancelButton")
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(SwiftRipButtonStyle(prominence: .secondary))

            Button {
                applySettings()
            } label: {
                Text(AppStrings.settingsOKTitle)
                    .frame(width: SwiftRipLayout.Button.dialogFooterWidth)
                    .accessibilityIdentifier("settingsOKButton")
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(SwiftRipButtonStyle(prominence: .primary))
        }
        .swiftRipDialogFooterPadding()
    }

    private var outputLocationRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(AppStrings.settingsOutputLocationTitle)
                .swiftRipSettingsLabel()
                .frame(width: SwiftRipLayout.SettingsWindow.labelWidth, alignment: .trailing)

            OutputDirectoryPathControl(url: draft.outputDirectoryURL)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 24)
                .accessibilityLabel(AppStrings.settingsOutputLocationTitle)
                .accessibilityValue(draft.outputDirectoryURL.path)
                .accessibilityIdentifier("outputDirectoryPathControl")
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
                    .accessibilityIdentifier("changeOutputDirectoryButton")
            }
            .buttonStyle(SwiftRipButtonStyle(prominence: .secondary))

            Button {
                draft.resetOutputDirectoryToDefault()
                outputDirectoryErrorMessage = nil
            } label: {
                Text(AppStrings.settingsResetTitle)
                    .frame(width: SwiftRipLayout.Button.settingsWidth)
                    .accessibilityIdentifier("resetOutputDirectoryButton")
            }
            .buttonStyle(SwiftRipButtonStyle(prominence: .secondary))
            .disabled(draft.isUsingDefaultOutputDirectory)

            Spacer(minLength: 0)
        }
    }

    private var filenameFormatRow: some View {
        HStack {
            Text(AppStrings.settingsFilenameFormatTitle)
                .swiftRipSettingsLabel()
                .frame(width: SwiftRipLayout.SettingsWindow.labelWidth, alignment: .trailing)

            Picker(AppStrings.settingsFilenameFormatTitle, selection: $draft.outputFilenameFormat) {
                ForEach(OutputFilenameFormat.allCases) { format in
                    Text(format.title)
                        .tag(format)
                }
            }
            .labelsHidden()
            .frame(width: 240, alignment: .leading)
            .accessibilityLabel(AppStrings.settingsFilenameFormatTitle)
            .accessibilityIdentifier("filenameFormatPicker")
        }
    }

    private var completionSoundRow: some View {
        HStack {
            Text(AppStrings.settingsCompletionSoundTitle)
                .swiftRipSettingsLabel()
                .frame(width: SwiftRipLayout.SettingsWindow.labelWidth, alignment: .trailing)

            Picker(AppStrings.settingsCompletionSoundTitle, selection: $draft.completionSound) {
                ForEach(CompletionSound.allCases) { sound in
                    Text(sound.title)
                        .tag(sound)
                }
            }
            .labelsHidden()
            .frame(width: 160, alignment: .leading)
            .accessibilityLabel(AppStrings.settingsCompletionSoundTitle)
            .accessibilityIdentifier("completionSoundPicker")
        }
    }

    private func dismissSettingsWindow() {
        NSApp.keyWindow?.close()
    }

    private func cancelSettings() {
        draft = SettingsDraft(settings: settings)
        dismissSettingsWindow()
    }

    private func applySettings() {
        do {
            try draft.apply(to: settings)
            outputDirectoryErrorMessage = nil
            dismissSettingsWindow()
        } catch {
            outputDirectoryErrorMessage = error.localizedDescription
        }
    }

    private func chooseOutputDirectory() {
        guard
            let url = OutputDirectoryPanel.chooseDirectory(
                defaultDirectoryURL: draft.outputDirectoryURL,
                prompt: AppStrings.settingsChangePrompt
            )
        else {
            return
        }

        draft.setOutputDirectory(url)
        outputDirectoryErrorMessage = nil
    }
}

#Preview {
    SettingsView()
}

private struct OutputDirectoryPathControl: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSPathControl {
        let pathControl = NSPathControl()
        pathControl.pathStyle = .standard
        pathControl.isEditable = false
        pathControl.controlSize = .regular
        pathControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return pathControl
    }

    func updateNSView(_ pathControl: NSPathControl, context: Context) {
        pathControl.url = url
    }
}
