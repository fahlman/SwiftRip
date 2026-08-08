//
//  AppMenuCleaner.swift
//  SwiftRip
//

import AppKit

@MainActor
enum AppMenuCleaner {

    static func configureWindowBehavior() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    static func removeUnusedMenus(from mainMenu: NSMenu?) {
        removeViewMenu(from: mainMenu)
    }

    static func removeViewMenu(from mainMenu: NSMenu?) {
        guard let mainMenu else { return }
        guard let viewMenuItem = mainMenu.items.first(where: containsFullScreenCommand) else {
            return
        }

        mainMenu.removeItem(viewMenuItem)
    }

    private static func containsFullScreenCommand(_ menuItem: NSMenuItem) -> Bool {
        menuItem.submenu?.containsAction(#selector(NSWindow.toggleFullScreen(_:))) == true
    }
}

private extension NSMenu {
    func containsAction(_ action: Selector) -> Bool {
        items.contains { item in
            item.action == action || item.submenu?.containsAction(action) == true
        }
    }
}
