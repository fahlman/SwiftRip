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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Window("About SwiftRip", id: "about-swiftrip") {
            AboutSwiftRipView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About SwiftRip") {
                    openWindow(id: "about-swiftrip")
                }
            }
        }
    }
}

private struct AboutSwiftRipView: View {
    private let appName = "SwiftRip"
    private let appDescription = "A small macOS DVD ripping tool built around bundled ARM64 ripping tools."

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 44))
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appName)
                        .font(.title2.bold())

                    Text(appVersionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(appDescription)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Bundled Tools")
                    .font(.headline)

                Label("HandBrakeCLI", systemImage: "terminal")
                Label("libdvdcss.2.dylib", systemImage: "shippingbox")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Licenses")
                    .font(.headline)

                Text("SwiftRip includes bundled third-party tools. Their license files are included in the app bundle under Resources/Licenses.")
                    .foregroundStyle(.secondary)

                if licenseNames.isEmpty {
                    Text("No bundled license files were found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(licenseNames, id: \.self) { name in
                        Label(name, systemImage: "doc.text")
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 520, height: 420)
    }

    private var appVersionText: String {
        let infoDictionary = Bundle.main.infoDictionary
        let version = infoDictionary?["CFBundleShortVersionString"] as? String
        let build = infoDictionary?["CFBundleVersion"] as? String

        switch (version, build) {
        case let (.some(version), .some(build)):
            return "Version \(version) (\(build))"
        case let (.some(version), .none):
            return "Version \(version)"
        case let (.none, .some(build)):
            return "Build \(build)"
        case (.none, .none):
            return "Version unknown"
        }
    }

    private var licenseNames: [String] {
        guard let licensesURL = Bundle.main.resourceURL?.appendingPathComponent("Licenses", isDirectory: true),
              let urls = try? FileManager.default.contentsOfDirectory(
                at: licensesURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return urls
            .filter { !$0.hasDirectoryPath }
            .map { $0.lastPathComponent }
            .sorted()
    }
}
