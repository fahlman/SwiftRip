//
//  SecurityScopedAccess.swift
//  SwiftRip
//

import Foundation

@MainActor
protocol SecurityScopedResourceAccess: AnyObject {
    var url: URL { get }
    var isAccessing: Bool { get }

    func stopAccessing()
}

@MainActor
protocol SecurityScopedResourceAccessProviding {
    func startAccessing(_ url: URL) -> any SecurityScopedResourceAccess
}

@MainActor
final class DefaultSecurityScopedResourceAccessProvider: SecurityScopedResourceAccessProviding {
    func startAccessing(_ url: URL) -> any SecurityScopedResourceAccess {
        SecurityScopedResourceAccessToken(url: url)
    }
}

@MainActor
final class SecurityScopedResourceAccessToken: SecurityScopedResourceAccess {
    let url: URL

    private(set) var isAccessing: Bool

    init(url: URL) {
        self.url = url
        self.isAccessing = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if isAccessing {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func stopAccessing() {
        guard isAccessing else { return }

        url.stopAccessingSecurityScopedResource()
        isAccessing = false
    }
}
