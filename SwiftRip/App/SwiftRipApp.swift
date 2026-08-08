//
//  SwiftRipApp.swift
//  SwiftRip
//

import AppKit
import Sparkle
import SwiftUI

@main
struct SwiftRipApp: App {

    @NSApplicationDelegateAdaptor(SwiftRipAppDelegate.self) private var appDelegate
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        Window(RipConfiguration.appName, id: "main") {
            ContentView()
        }
        .defaultSize(
            width: SwiftRipLayout.MainWindow.defaultWidth,
            height: SwiftRipLayout.MainWindow.defaultHeight
        )
        .defaultPosition(.center)
        .commands {
            SwiftRipCommands(updaterController: updaterController)
        }

        Settings {
            SettingsView()
        }
        .defaultSize(
            width: SwiftRipLayout.SettingsWindow.defaultWidth,
            height: SwiftRipLayout.SettingsWindow.defaultHeight
        )
        .windowResizability(.contentMinSize)
    }
}

@MainActor
final class SwiftRipAppDelegate: NSObject, NSApplicationDelegate {

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let coordinator = RipInterruptionCoordinator.shared

        guard coordinator.shouldConfirmAppQuit else {
            return .terminateNow
        }

        coordinator.requestAppQuitConfirmation()
        return .terminateCancel
    }
}
