//
//  AppMenuCleanerTests.swift
//  SwiftRipTests
//

import AppKit
import Testing
@testable import SwiftRip

@MainActor
struct AppMenuCleanerTests {

    @Test func removesMenuContainingFullScreenCommand() {
        let mainMenu = NSMenu()
        mainMenu.addItem(menuItem(title: "SwiftRip"))
        mainMenu.addItem(menuItem(title: "File"))
        mainMenu.addItem(menuItem(title: "Display", actions: [
            nil,
            #selector(NSWindow.toggleFullScreen(_:))
        ]))

        AppMenuCleaner.removeViewMenu(from: mainMenu)

        #expect(mainMenu.items.map(\.title) == ["SwiftRip", "File"])
    }

    @Test func leavesMenusWithoutFullScreenCommandAlone() {
        let mainMenu = NSMenu()
        mainMenu.addItem(menuItem(title: "SwiftRip"))
        mainMenu.addItem(menuItem(title: "File"))
        mainMenu.addItem(menuItem(title: "Window", actions: [
            #selector(NSWindow.performMiniaturize(_:)),
            #selector(NSWindow.performZoom(_:))
        ]))

        AppMenuCleaner.removeViewMenu(from: mainMenu)

        #expect(mainMenu.items.map(\.title) == ["SwiftRip", "File", "Window"])
    }

    private func menuItem(title: String, actions: [Selector?] = []) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)

        for (index, action) in actions.enumerated() {
            submenu.addItem(NSMenuItem(
                title: "Item \(index)",
                action: action,
                keyEquivalent: ""
            ))
        }

        item.submenu = submenu
        return item
    }
}
