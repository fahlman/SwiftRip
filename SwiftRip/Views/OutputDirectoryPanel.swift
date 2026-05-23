//
//  OutputDirectoryPanel.swift
//  SwiftRip
//

import AppKit
import Foundation

enum OutputDirectoryPanel {
    @MainActor
    static func chooseDirectory(
        defaultDirectoryURL: URL?,
        prompt: String,
        message: String? = nil
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = defaultDirectoryURL
        panel.prompt = prompt
        panel.message = message

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
