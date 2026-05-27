//
//  RipLogWriter.swift
//  SwiftRip
//

import Foundation

protocol RipLogWriting: Sendable {
    func start(log: RipLog) async -> Error?
    func append(_ text: String) async -> Error?
}

actor FileRipLogWriter: RipLogWriting {
    private var url: URL?
    private var directoryURL: URL?
    private var hasStarted = false

    func start(log: RipLog) async -> Error? {
        do {
            url = log.url
            directoryURL = log.directoryURL
            try FileManager.default.createDirectory(at: log.directoryURL, withIntermediateDirectories: true)
            try log.text.write(to: log.url, atomically: true, encoding: .utf8)
            hasStarted = true
            return nil
        } catch {
            return error
        }
    }

    func append(_ text: String) async -> Error? {
        guard !text.isEmpty else { return nil }

        if !hasStarted {
            return nil
        }

        do {
            guard let url else { return nil }
            let handle = try FileHandle(forWritingTo: url)
            defer {
                try? handle.close()
            }

            try handle.seekToEnd()
            if let data = text.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
            return nil
        } catch {
            return error
        }
    }
}
