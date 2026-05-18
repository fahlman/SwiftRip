//
//  ContentView.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = RipViewModel()
    @State private var isDVDPickerPresented = false

    private static let chooseDVDTitle = "Choose DVD…"
    private static let ripTitle = "Rip"
    private static let stopTitle = "Stop"
    private static let noValidDVDTitle = "No valid DVD"
    private static let opticalDiscIconName = "opticaldisc"
    private static let selectedOpticalDiscIconName = "opticaldisc.fill"
    private static let ripIconName = "arrow.trianglehead.2.clockwise"
    private static let stopIconName = "stop.fill"
    private static let selectedBadgeIconName = "checkmark.circle.fill"
    private static let missingBadgeIconName = "questionmark.circle.fill"

    private enum PrimaryButtonState {
        case chooseDVD
        case rip
        case stop

        var title: String {
            switch self {
            case .chooseDVD:
                return ContentView.chooseDVDTitle
            case .rip:
                return ContentView.ripTitle
            case .stop:
                return ContentView.stopTitle
            }
        }

        var systemImage: String {
            switch self {
            case .chooseDVD:
                return ContentView.opticalDiscIconName
            case .rip:
                return ContentView.ripIconName
            case .stop:
                return ContentView.stopIconName
            }
        }
    }

    private var primaryButtonState: PrimaryButtonState {
        if viewModel.isEncoding {
            return .stop
        }

        if viewModel.selectedDVD == nil {
            return .chooseDVD
        }

        return .rip
    }

    var body: some View {
        VStack(spacing: 16) {
            dvdIcon
            dvdLabel
            primaryButton
            statusSection
        }
        .padding(18)
        .frame(width: 272, height: 300)
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
            viewModel.cancelRip()
        }
    }

    private var dvdIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            if viewModel.selectedDVD != nil {
                Image(systemName: Self.selectedOpticalDiscIconName)
                    .font(.system(size: 104, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .symbolEffect(.rotate.byLayer, options: .repeat(.continuous), isActive: viewModel.isEncoding)

                Image(systemName: Self.selectedBadgeIconName)
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
                    .offset(x: 6, y: 4)
            } else {
                Image(systemName: Self.opticalDiscIconName)
                    .font(.system(size: 104, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .opacity(0.45)

                Image(systemName: Self.missingBadgeIconName)
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black, .gray)
                    .offset(x: 6, y: 4)
            }
        }
        .frame(width: 122, height: 114)
        .accessibilityElement(children: .combine)
    }

    private var dvdLabel: some View {
        VStack(spacing: 4) {
            Text(viewModel.selectedDVD?.name ?? Self.noValidDVDTitle)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)
        }
    }

    private var primaryButton: some View {
        Button {
            performPrimaryButtonAction()
        } label: {
            Label(primaryButtonState.title, systemImage: primaryButtonState.systemImage)
                .frame(width: 116)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func performPrimaryButtonAction() {
        switch primaryButtonState {
        case .chooseDVD:
            isDVDPickerPresented = true
        case .rip:
            Task {
                await viewModel.startRip { outputURL in
                    NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                }
            }
        case .stop:
            viewModel.cancelRip()
        }
    }

    private var statusSection: some View {
        VStack(spacing: 10) {
            ProgressView(value: viewModel.progress)
                .frame(width: 180)

            Text("\(Int(viewModel.progress * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .opacity(viewModel.isEncoding ? 1 : 0)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
