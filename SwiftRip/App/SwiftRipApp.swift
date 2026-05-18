//
//  SwiftRipApp.swift
//  SwiftRip
//

import SwiftUI

@main
struct SwiftRipApp: App {

    @Environment(\.openWindow) private var openWindow

    private static let aboutWindowID = "about-swiftrip"
    private static let aboutTitle = AppStrings.aboutTitle(appName: RipConfiguration.appName)

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            SwiftRipCommands {
                openWindow(id: Self.aboutWindowID)
            }
        }

        Settings {
            SettingsView()
        }

        Window(Self.aboutTitle, id: Self.aboutWindowID) {
            AboutSwiftRipView()
        }
        .commandsRemoved()
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
