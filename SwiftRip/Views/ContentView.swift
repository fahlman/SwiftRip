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
    @State private var hasPresentedInitialOutputDirectoryPrompt = false
    @State private var hasRunLaunchAutomation = false

    private static let chooseDVDTitle = AppStrings.chooseDVDTitle

    var body: some View {
        VStack(spacing: SwiftRipLayout.MainWindow.contentSpacing) {
            DVDStatusView(
                hasSelectedDVD: viewModel.hasSelectedDVD,
                isEncoding: viewModel.isEncoding,
                displayName: viewModel.dvdDisplayName,
                accessibilityValue: dvdStatusAccessibilityValue
            )

            PrimaryRipButton(title: viewModel.primaryAction.title) {
                performPrimaryButtonAction()
            }

            if viewModel.isEncoding {
                RipProgressSection(progress: viewModel.progress)
                    .transition(.opacity)
            }
        }
        .padding(SwiftRipLayout.MainWindow.contentPadding)
        .swiftRipWindowFrame(
            width: SwiftRipLayout.MainWindow.width,
            height: mainWindowHeight,
            alignment: .top
        )
        .fixedSize()
        .fileImporter(
            isPresented: $isDVDPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleDVDPickerResult(result)
        }
        .fileDialogDefaultDirectory(URL(fileURLWithPath: "/Volumes", isDirectory: true))
        .fileDialogConfirmationLabel(Self.chooseDVDTitle)
        .onDisappear {
            viewModel.cancelRipForWindowCloseOrAppQuit()
        }
        .onAppear {
            viewModel.refreshDVDs()
            interruptionCoordinator.isRipActive = viewModel.isEncoding
            Task { @MainActor in
                await Task.yield()
                presentInitialOutputDirectoryPromptIfNeeded()
                runLaunchAutomationIfNeeded()
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
        .focusedSceneValue(\.ripCommandActions, ripCommandActions)
    }

    private func performPrimaryButtonAction() {
        ripCommandActions.perform(viewModel.primaryAction)
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
            return AppStrings.ripping(selectedDVDName)
        }

        return viewModel.dvdDisplayName
    }

    private func startRip() {
        guard ensureOutputDirectoryPermission(message: AppStrings.outputFolderPermissionMessage) else { return }

        Task {
            await viewModel.startRip { outputURL in
                NSWorkspace.shared.activateFileViewerSelecting([outputURL])
            }
        }
    }

    private func presentInitialOutputDirectoryPromptIfNeeded() {
        guard !hasPresentedInitialOutputDirectoryPrompt else { return }
        guard !FirstRunOutputPermissionPrompter.isSuppressed() else { return }
        guard FirstRunOutputPermissionPrompter.isForced() || viewModel.needsOutputDirectoryPermission else { return }

        hasPresentedInitialOutputDirectoryPrompt = true
        _ = ensureOutputDirectoryPermission(
            message: AppStrings.firstRunOutputFolderMessage,
            force: FirstRunOutputPermissionPrompter.isForced()
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
            AppAlertPresenter.showWarning(
                messageText: AppStrings.invalidDVDSelectionTitle,
                informativeText: AppStrings.chooseVideoTSFolder(directoryName: DVDVolume.videoTSDirectoryName)
            )
        }
    }

    private func ensureOutputDirectoryPermission(message: String, force: Bool = false) -> Bool {
        guard force || viewModel.needsOutputDirectoryPermission else { return true }

        guard
            let url = OutputDirectoryPanel.chooseDirectory(
                defaultDirectoryURL: viewModel.defaultOutputDirectory,
                prompt: AppStrings.chooseOutputFolderPrompt,
                message: message
            )
        else {
            return false
        }

        do {
            try viewModel.setOutputDirectory(url)
            return true
        } catch {
            AppAlertPresenter.showWarning(
                messageText: AppStrings.outputFolderPermissionFailedTitle,
                informativeText: error.localizedDescription
            )
            return false
        }
    }

    private func stopRip() {
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

    private var mainWindowHeight: CGFloat {
        viewModel.isEncoding ? SwiftRipLayout.MainWindow.encodingHeight : SwiftRipLayout.MainWindow.height
    }
}

#Preview {
    ContentView()
}
