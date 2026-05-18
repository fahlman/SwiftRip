//
//  SwiftRipApp.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
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
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
