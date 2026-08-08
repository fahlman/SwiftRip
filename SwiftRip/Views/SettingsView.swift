//
//  SettingsView.swift
//  SwiftRip
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var outputDirectoryErrorMessage: String?
    @State private var isOutputDirectoryPickerPresented = false
    @State private var selection: SettingsPane? = .files

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(
                min: SwiftRipLayout.SettingsWindow.sidebarMinWidth,
                ideal: SwiftRipLayout.SettingsWindow.sidebarIdealWidth,
                max: SwiftRipLayout.SettingsWindow.sidebarMaxWidth
            )
        } detail: {
            Form {
                switch selection ?? .files {
                case .files:
                    Section {
                        filesSection
                    }

                case .completion:
                    Section {
                        completionSection
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
            .navigationTitle((selection ?? .files).title)
        }
        .frame(
            minWidth: SwiftRipLayout.SettingsWindow.minWidth,
            minHeight: SwiftRipLayout.SettingsWindow.minHeight
        )
        .fileImporter(
            isPresented: $isOutputDirectoryPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleOutputDirectoryPickerResult(result)
        }
        .fileDialogDefaultDirectory(settings.outputDirectoryURL)
        .fileDialogConfirmationLabel(AppStrings.settingsChangePrompt)
        .accessibilityIdentifier("settingsWindow")
    }

    private var filesSection: some View {
        Group {
            outputLocationRow
            outputLocationControls
            filenameFormatRow

            if let outputDirectoryErrorMessage {
                Text(outputDirectoryErrorMessage)
                    .foregroundStyle(SwiftRipColors.errorText)
                    .accessibilityIdentifier("outputDirectoryErrorMessage")
            }
        }
    }

    private var completionSection: some View {
        Group {
            completionSoundRow

            Toggle(AppStrings.settingsNotificationTitle, isOn: isCompletionNotificationEnabledBinding)
                .accessibilityIdentifier("completionNotificationToggle")

            Toggle(AppStrings.settingsRevealCompletedFileTitle, isOn: shouldRevealCompletedFileBinding)
                .accessibilityIdentifier("revealCompletedFileToggle")

            Toggle(AppStrings.settingsAutoEjectTitle, isOn: shouldAutoEjectAfterSuccessfulRipBinding)
                .accessibilityIdentifier("autoEjectToggle")
        }
    }

    private var outputLocationRow: some View {
        LabeledContent(AppStrings.settingsOutputLocationTitle) {
            OutputDirectoryLocationView(url: settings.outputDirectoryURL)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(AppStrings.settingsOutputLocationTitle)
                .accessibilityValue(settings.outputDirectoryURL.path(percentEncoded: false))
                .accessibilityIdentifier("outputDirectoryPathControl")
        }
    }

    private var outputLocationControls: some View {
        HStack {
            Spacer()

            Button {
                isOutputDirectoryPickerPresented = true
            } label: {
                Text(AppStrings.settingsChangeTitle)
                    .accessibilityIdentifier("changeOutputDirectoryButton")
            }
            .buttonStyle(.bordered)

            Button {
                settings.resetOutputDirectoryToMovies()
                outputDirectoryErrorMessage = nil
            } label: {
                Text(AppStrings.settingsResetTitle)
                    .accessibilityIdentifier("resetOutputDirectoryButton")
            }
            .buttonStyle(.bordered)
            .disabled(settings.isUsingDefaultOutputDirectory)
        }
    }

    private var filenameFormatRow: some View {
        Picker(AppStrings.settingsFilenameFormatTitle, selection: outputFilenameFormatBinding) {
            ForEach(OutputFilenameFormat.allCases) { format in
                Text(format.title)
                    .tag(format)
            }
        }
        .accessibilityLabel(AppStrings.settingsFilenameFormatTitle)
        .accessibilityIdentifier("filenameFormatPicker")
    }

    private var completionSoundRow: some View {
        Picker(AppStrings.settingsCompletionSoundTitle, selection: completionSoundBinding) {
            ForEach(CompletionSound.allCases) { sound in
                Text(sound.title)
                    .tag(sound)
            }
        }
        .accessibilityLabel(AppStrings.settingsCompletionSoundTitle)
        .accessibilityIdentifier("completionSoundPicker")
    }

    private var outputFilenameFormatBinding: Binding<OutputFilenameFormat> {
        Binding {
            settings.outputFilenameFormat
        } set: {
            settings.outputFilenameFormat = $0
        }
    }

    private var completionSoundBinding: Binding<CompletionSound> {
        Binding {
            settings.completionSound
        } set: {
            settings.completionSound = $0
        }
    }

    private var isCompletionNotificationEnabledBinding: Binding<Bool> {
        Binding {
            settings.isCompletionNotificationEnabled
        } set: {
            settings.isCompletionNotificationEnabled = $0
        }
    }

    private var shouldRevealCompletedFileBinding: Binding<Bool> {
        Binding {
            settings.shouldRevealCompletedFile
        } set: {
            settings.shouldRevealCompletedFile = $0
        }
    }

    private var shouldAutoEjectAfterSuccessfulRipBinding: Binding<Bool> {
        Binding {
            settings.shouldAutoEjectAfterSuccessfulRip
        } set: {
            settings.shouldAutoEjectAfterSuccessfulRip = $0
        }
    }

    private func handleOutputDirectoryPickerResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        do {
            try settings.setOutputDirectory(url)
            outputDirectoryErrorMessage = nil
        } catch {
            outputDirectoryErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case files
    case completion

    var id: Self { self }

    var title: String {
        switch self {
        case .files:
            AppStrings.settingsFilesTitle
        case .completion:
            AppStrings.settingsCompletionTitle
        }
    }

    var systemImage: String {
        switch self {
        case .files:
            SwiftRipSymbols.folder
        case .completion:
            SwiftRipSymbols.completion
        }
    }
}

private struct OutputDirectoryLocationView: View {
    let url: URL

    var body: some View {
        HStack {
            Text(displayPath)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .foregroundStyle(.tint)
        }
        .help(fullPath)
    }

    private var displayPath: String {
        fullPath
    }

    private var fullPath: String {
        url.path(percentEncoded: false)
    }
}
