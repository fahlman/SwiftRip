//
//  OutputURLResolver.swift
//  SwiftRip
//

import Foundation

struct OutputURLResolver {
    private static let movieFileExtension = "m4v"
    private static let maximumNumberedCandidate = 10_000

    let fileManager: FileManager

    func normalizedMovieURL(for url: URL) -> URL {
        url.pathExtension.lowercased() == Self.movieFileExtension
            ? url
            : url.deletingPathExtension().appendingPathExtension(Self.movieFileExtension)
    }

    func availableURL(for url: URL) -> URL {
        guard fileManager.fileExists(atPath: url.path) else {
            return url
        }

        let directoryURL = url.deletingLastPathComponent()
        let fileExtension = url.pathExtension
        let baseName = url.deletingPathExtension().lastPathComponent

        for index in 2...Self.maximumNumberedCandidate {
            let candidateURL = directoryURL
                .appendingPathComponent("\(baseName) \(index)")
                .appendingPathExtension(fileExtension)

            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        return directoryURL
            .appendingPathComponent("\(baseName) \(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
    }
}
