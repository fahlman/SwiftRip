//
//  ContentView.swift
//  SwiftRip
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = RipViewModel()
    @State private var interruptionCoordinator = RipInterruptionCoordinator.shared
    @State private var isDVDPickerPresented = false

    private static let chooseDVDTitle = AppStrings.chooseDVDTitle
    private static let noValidDVDTitle = AppStrings.noValidDVDTitle

    var body: some View {
        VStack(spacing: SwiftRipLayout.MainWindow.contentSpacing) {
            dvdIcon
            dvdLabel
            primaryButton
            statusSection
        }
        .padding(SwiftRipLayout.MainWindow.contentPadding)
        .swiftRipWindowFrame(width: SwiftRipLayout.MainWindow.width, height: SwiftRipLayout.MainWindow.height)
        .fixedSize()
        .fileImporter(
            isPresented: $isDVDPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.chooseDVD(at: url)
            }
        }
        .fileDialogDefaultDirectory(URL(fileURLWithPath: "/Volumes", isDirectory: true))
        .fileDialogConfirmationLabel(Self.chooseDVDTitle)
        .onDisappear {
            viewModel.cancelRipForWindowCloseOrAppQuit()
        }
        .onAppear {
            interruptionCoordinator.isRipActive = viewModel.isEncoding
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

    private var dvdIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            discImage
            discBadge
        }
        .frame(
            width: SwiftRipLayout.MainWindow.discIconFrameWidth,
            height: SwiftRipLayout.MainWindow.discIconFrameHeight
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppStrings.dvdStatusAccessibilityLabel)
        .accessibilityValue(dvdStatusAccessibilityValue)
        .accessibilityIdentifier("dvdStatus")
    }

    private var discImage: some View {
        Image(systemName: hasSelectedDVD ? SwiftRipSymbols.selectedOpticalDisc : SwiftRipSymbols.opticalDisc)
            .font(.system(size: SwiftRipLayout.MainWindow.discIconSize, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(SwiftRipColors.discIcon)
            .opacity(hasSelectedDVD ? 1 : 0.45)
            .symbolEffect(.rotate.byLayer, options: .repeat(.continuous), isActive: viewModel.isEncoding && !reduceMotion)
    }

    private var discBadge: some View {
        Image(systemName: hasSelectedDVD ? SwiftRipSymbols.selectedBadge : SwiftRipSymbols.missingBadge)
            .font(.system(size: SwiftRipLayout.MainWindow.badgeIconSize, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                hasSelectedDVD ? SwiftRipColors.selectedBadgeForeground : SwiftRipColors.missingBadgeForeground,
                hasSelectedDVD ? SwiftRipColors.selectedBadgeBackground : SwiftRipColors.missingBadgeBackground
            )
            .offset(
                x: SwiftRipLayout.MainWindow.badgeOffsetX,
                y: SwiftRipLayout.MainWindow.badgeOffsetY
            )
    }

    private var dvdLabel: some View {
        VStack(spacing: 4) {
            Text(viewModel.selectedDVDName ?? Self.noValidDVDTitle)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("dvdName")
        }
    }

    private var primaryButton: some View {
        Button {
            performPrimaryButtonAction()
        } label: {
            Text(viewModel.primaryAction.title)
                .frame(width: SwiftRipLayout.Button.mainWidth)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(SwiftRipButtonStyle(prominence: .primary))
        .controlSize(.large)
        .accessibilityIdentifier("primaryActionButton")
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
        isDVDPickerPresented = true
    }

    private var hasSelectedDVD: Bool {
        viewModel.hasSelectedDVD
    }

    private var dvdStatusAccessibilityValue: String {
        if viewModel.isEncoding, let selectedDVDName = viewModel.selectedDVDName {
            return AppStrings.ripping(selectedDVDName)
        }

        return viewModel.selectedDVDName ?? Self.noValidDVDTitle
    }

    private func startRip() {
        Task {
            await viewModel.startRip { outputURL in
                NSWorkspace.shared.activateFileViewerSelecting([outputURL])
            }
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

    private var statusSection: some View {
        Group {
            if viewModel.isEncoding {
                progressSection
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: SwiftRipLayout.MainWindow.statusHeight)
    }

    private var progressSection: some View {
        VStack(spacing: SwiftRipLayout.MainWindow.statusSpacing) {
            ProgressView(value: viewModel.progress)
                .frame(width: SwiftRipLayout.MainWindow.progressWidth)
                .accessibilityLabel(AppStrings.progressAccessibilityLabel)
                .accessibilityValue(AppStrings.percentComplete(progressPercent))
                .accessibilityIdentifier("ripProgress")

            Text("\(progressPercent)%")
                .swiftRipProgressCaption()
                .accessibilityHidden(true)
        }
    }

    private var progressPercent: Int {
        Int(viewModel.progress * 100)
    }
}

#Preview {
    ContentView()
}

enum RipInterruptionRequest {
    case windowClose
    case appQuit
}

@MainActor
@Observable
final class RipInterruptionCoordinator {
    static let shared = RipInterruptionCoordinator()

    var isRipActive = false
    private(set) var pendingRequest: RipInterruptionRequest?
    private(set) var shouldAllowConfirmedAppQuit = false
    private(set) var shouldAllowConfirmedWindowClose = false

    @ObservationIgnored
    weak var pendingWindow: NSWindow?

    var hasPendingRequest: Bool {
        pendingRequest != nil
    }

    var shouldConfirmAppQuit: Bool {
        isRipActive && !shouldAllowConfirmedAppQuit
    }

    func updateRipActivity(_ isRipActive: Bool) {
        self.isRipActive = isRipActive

        if !isRipActive {
            clearPendingRequest()
        }
    }

    func shouldConfirmWindowClose(_ window: NSWindow) -> Bool {
        guard isRipActive, !shouldAllowConfirmedWindowClose else { return false }

        pendingWindow = window
        pendingRequest = .windowClose
        return true
    }

    func requestAppQuitConfirmation() {
        pendingRequest = .appQuit
    }

    func clearPendingRequest() {
        pendingRequest = nil
        pendingWindow = nil
        shouldAllowConfirmedAppQuit = false
        shouldAllowConfirmedWindowClose = false
    }

    func closePendingWindowAfterConfirmation() {
        shouldAllowConfirmedWindowClose = true
        let window = pendingWindow
        pendingRequest = nil
        pendingWindow = nil
        window?.performClose(nil)
        shouldAllowConfirmedWindowClose = false
    }

    func quitAppAfterConfirmation() {
        pendingRequest = nil
        pendingWindow = nil
        shouldAllowConfirmedAppQuit = true
        NSApp.terminate(nil)
    }
}

private struct WindowCloseConfirmationGate: NSViewRepresentable {

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window, window.delegate !== context.coordinator else { return }
            context.coordinator.previousDelegate = window.delegate
            window.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        weak var previousDelegate: NSWindowDelegate?

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if RipInterruptionCoordinator.shared.shouldConfirmWindowClose(sender) {
                return false
            }

            return previousDelegate?.windowShouldClose?(sender) ?? true
        }
    }
}
