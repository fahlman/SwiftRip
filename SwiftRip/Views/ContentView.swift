//
//  ContentView.swift
//  SwiftRip
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = RipViewModel()
    @State private var interruptionCoordinator = RipInterruptionCoordinator.shared
    @State private var isDVDPickerPresented = false
    @State private var isOutputDirectoryPickerPresented = false
    @State private var outputDirectoryPickerPurpose: OutputDirectoryPickerPurpose?
    @State private var outputDirectoryPickerMessage: String?
    @State private var activeAlert: AppAlert?
    @State private var hasPresentedUsageNotice = false
    @State private var hasPresentedInitialOutputDirectoryPrompt = false
    @State private var hasRunLaunchAutomation = false

    private static let chooseDVDTitle = AppStrings.chooseDVDTitle

    var body: some View {
        DVDStatusView(
            hasSelectedDVD: viewModel.hasSelectedDVD,
            isEncoding: viewModel.isEncoding,
            progress: viewModel.progress,
            remainingTimeText: remainingTimeText,
            displayName: viewModel.dvdDisplayName,
            accessibilityValue: dvdStatusAccessibilityValue
        )
        .padding()
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .fileImporter(
            isPresented: $isDVDPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleDVDPickerResult(result)
        }
        .fileDialogDefaultDirectory(URL(fileURLWithPath: "/Volumes", isDirectory: true))
        .fileDialogConfirmationLabel(Self.chooseDVDTitle)
        .fileImporter(
            isPresented: $isOutputDirectoryPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleOutputDirectoryPickerResult(result)
        }
        .fileDialogDefaultDirectory(viewModel.defaultOutputDirectory)
        .fileDialogConfirmationLabel(AppStrings.chooseOutputFolderPrompt)
        .fileDialogMessage(outputDirectoryPickerMessage.map(Text.init))
        .onDisappear {
            viewModel.cancelRipForWindowCloseOrAppQuit()
        }
        .onAppear {
            viewModel.refreshDVDs()
            interruptionCoordinator.isRipActive = viewModel.isEncoding
            Task { @MainActor in
                await Task.yield()
                continueLaunchAutomationIfAllowed()
            }
        }
        .onChange(of: viewModel.isEncoding) { _, isEncoding in
            interruptionCoordinator.updateRipActivity(isEncoding)
        }
        .background(WindowCloseConfirmationGate())
        .alert(AppStrings.stopRipConfirmationTitle, isPresented: stopRipConfirmationBinding) {
            Button(AppStrings.keepRippingTitle, role: .cancel) {
                interruptionCoordinator.clearPendingRequest()
            }

            Button(AppStrings.stopTitle, role: .destructive) {
                confirmStopRipForInterruption()
            }
        } message: {
            Text(AppStrings.stopRipConfirmationMessage)
        }
        .alert(activeAlertTitle, isPresented: activeAlertBinding, presenting: activeAlert) { alert in
            switch alert.kind {
            case .warning:
                Button(AppStrings.settingsOKTitle) {}
            case .usageNotice:
                Button(AppStrings.usageNoticeAcknowledgeTitle) {
                    acknowledgeUsageNotice()
                }

                Button(AppStrings.quitTitle, role: .cancel) {
                    NSApp.terminate(nil)
                }
            }
        } message: { alert in
            Text(alert.message)
        }
        .toolbar {
            RipToolbar(actions: ripCommandActions)
        }
        .focusedSceneValue(\.ripCommandActions, ripCommandActions)
    }

    private var ripCommandActions: RipCommandActions {
        RipCommandActions(
            availability: viewModel.commandAvailability,
            chooseDVD: chooseDVD,
            rip: startRip,
            stop: stopRip,
            eject: ejectDVD,
            revealOutput: revealOutput,
            revealLog: revealLog
        )
    }

    private func chooseDVD() {
        guard viewModel.commandAvailability.canChooseDVD else { return }

        isDVDPickerPresented = true
    }

    private func handleDVDPickerResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard viewModel.commandAvailability.canChooseDVD else { return }

        chooseDVD(at: url)
    }

    private var dvdStatusAccessibilityValue: String {
        if viewModel.isEncoding, let selectedDVDName = viewModel.selectedDVDName {
            return ([
                AppStrings.ripping(selectedDVDName),
                AppStrings.percentComplete(progressPercent),
                remainingTimeText
            ] as [String?])
                .compactMap(\.self)
                .joined(separator: " ")
        }

        return viewModel.dvdDisplayName
    }

    private var progressPercent: Int {
        Int(min(max(viewModel.progress, 0), 1) * 100)
    }

    private var remainingTimeText: String? {
        guard viewModel.isEncoding, let estimatedRemainingTime = viewModel.estimatedRemainingTime else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let now = Date()
        return formatter.localizedString(
            for: Date(timeInterval: max(estimatedRemainingTime, 0), since: now),
            relativeTo: now
        )
    }

    private func startRip() {
        guard viewModel.commandAvailability.canRip else { return }
        guard !viewModel.needsOutputDirectoryPermission else {
            presentOutputDirectoryPicker(
                purpose: .startRip,
                message: AppStrings.outputFolderPermissionMessage
            )
            return
        }

        startRipAfterOutputPermission()
    }

    private func startRipAfterOutputPermission() {
        Task {
            await viewModel.startRip { outputURL in
                NSWorkspace.shared.activateFileViewerSelecting([outputURL])
            }
        }
    }

    private func continueLaunchAutomationIfAllowed() {
        guard presentUsageNoticeIfNeeded() else { return }
        presentInitialOutputDirectoryPromptIfNeeded()
        runLaunchAutomationIfNeeded()
    }

    private func presentUsageNoticeIfNeeded() -> Bool {
        guard !hasPresentedUsageNotice else { return true }
        guard !FirstRunUsageNoticePrompter.isSuppressed() else { return true }
        guard !viewModel.hasAcknowledgedCurrentUsageNotice else { return true }

        hasPresentedUsageNotice = true
        activeAlert = .usageNotice
        return false
    }

    private func acknowledgeUsageNotice() {
        viewModel.acknowledgeCurrentUsageNotice()
        continueLaunchAutomationIfAllowed()
    }

    private func presentInitialOutputDirectoryPromptIfNeeded() {
        guard !hasPresentedInitialOutputDirectoryPrompt else { return }
        guard !FirstRunOutputPermissionPrompter.isSuppressed() else { return }
        guard FirstRunOutputPermissionPrompter.isForced() || viewModel.needsOutputDirectoryPermission else { return }

        hasPresentedInitialOutputDirectoryPrompt = true
        presentOutputDirectoryPicker(
            purpose: .firstRun,
            message: AppStrings.firstRunOutputFolderMessage
        )
    }

    private func runLaunchAutomationIfNeeded() {
        guard !hasRunLaunchAutomation else { return }
        hasRunLaunchAutomation = true

        guard let invalidDVDPath = AppLaunchConfiguration.value(for: "SWIFTRIP_UI_TEST_INVALID_DVD_PATH") else {
            return
        }

        chooseDVD(at: URL(fileURLWithPath: invalidDVDPath, isDirectory: true))
    }

    private func chooseDVD(at url: URL) {
        if !viewModel.chooseDVD(at: url) {
            activeAlert = .warning(
                title: AppStrings.invalidDVDSelectionTitle,
                message: AppStrings.chooseVideoTSFolder(directoryName: DVDVolume.videoTSDirectoryName)
            )
        }
    }

    private func presentOutputDirectoryPicker(
        purpose: OutputDirectoryPickerPurpose,
        message: String
    ) {
        outputDirectoryPickerPurpose = purpose
        outputDirectoryPickerMessage = message
        isOutputDirectoryPickerPresented = true
    }

    private func handleOutputDirectoryPickerResult(_ result: Result<[URL], Error>) {
        let purpose = outputDirectoryPickerPurpose
        outputDirectoryPickerPurpose = nil
        outputDirectoryPickerMessage = nil

        guard case .success(let urls) = result, let url = urls.first else { return }

        setOutputDirectory(url, purpose: purpose)
    }

    private func setOutputDirectory(_ url: URL, purpose: OutputDirectoryPickerPurpose?) {
        do {
            try viewModel.setOutputDirectory(url)
        } catch {
            activeAlert = .warning(
                title: AppStrings.outputFolderPermissionFailedTitle,
                message: error.localizedDescription
            )
            return
        }

        if purpose == .startRip {
            startRipAfterOutputPermission()
        }
    }

    private func stopRip() {
        guard viewModel.commandAvailability.canStop else { return }

        viewModel.cancelRip()
    }

    private var stopRipConfirmationBinding: Binding<Bool> {
        Binding {
            interruptionCoordinator.hasPendingRequest
        } set: { isPresented in
            if !isPresented {
                interruptionCoordinator.clearPendingRequest()
            }
        }
    }

    private func confirmStopRipForInterruption() {
        let pendingRequest = interruptionCoordinator.pendingRequest

        viewModel.cancelRipForWindowCloseOrAppQuit()

        switch pendingRequest {
        case .windowClose:
            interruptionCoordinator.closePendingWindowAfterConfirmation()
        case .appQuit:
            interruptionCoordinator.quitAppAfterConfirmation()
        case nil:
            interruptionCoordinator.clearPendingRequest()
        }
    }

    private func ejectDVD() {
        guard viewModel.commandAvailability.canEject else { return }

        viewModel.ejectCompletedDVD()
    }

    private func revealOutput() {
        guard let outputURL = viewModel.outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
    }

    private func revealLog() {
        guard let logFileURL = viewModel.logFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
    }

}

private enum FirstRunUsageNoticePrompter {
    static func isSuppressed(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        if AppLaunchConfiguration.isRunningUnderXCTest(environment: environment, arguments: arguments) {
            return true
        }

        return AppLaunchConfiguration.isEnabled(
            "SWIFTRIP_SUPPRESS_USAGE_NOTICE",
            environment: environment,
            arguments: arguments
        )
    }
}

#Preview {
    ContentView()
}

private enum OutputDirectoryPickerPurpose {
    case firstRun
    case startRip
}

private struct AppAlert: Identifiable {
    enum Kind {
        case usageNotice
        case warning
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String

    static var usageNotice: AppAlert {
        AppAlert(
            kind: .usageNotice,
            title: AppStrings.usageNoticeTitle,
            message: AppStrings.usageNoticeMessage
        )
    }

    static func warning(title: String, message: String) -> AppAlert {
        AppAlert(kind: .warning, title: title, message: message)
    }
}

private extension ContentView {
    var activeAlertTitle: String {
        activeAlert?.title ?? ""
    }

    var activeAlertBinding: Binding<Bool> {
        Binding {
            activeAlert != nil
        } set: { isPresented in
            if !isPresented {
                activeAlert = nil
            }
        }
    }
}
