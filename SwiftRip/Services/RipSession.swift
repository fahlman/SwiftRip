//
//  RipSession.swift
//  SwiftRip
//
//  Created by Ryan Fahlsing on 5/16/26.
//

import Foundation

struct RipSession {
    let input: DVDVolume
    let outputURL: URL
    let arguments: [String]
    var log: RipLog
    private(set) var shouldDeleteOutputOnCancel = true

    init(
        input: DVDVolume,
        outputURL: URL,
        arguments: [String],
        logDirectoryURL: URL,
        executablePath: String,
        libdvdcssPath: String,
        presetURL: URL
    ) {
        self.input = input
        self.outputURL = outputURL
        self.arguments = arguments

        let logURL = RipLog.makeFileURL(for: input, in: logDirectoryURL)
        self.log = RipLog(
            input: input,
            outputURL: outputURL,
            arguments: arguments,
            executablePath: executablePath,
            libdvdcssPath: libdvdcssPath,
            presetURL: presetURL,
            url: logURL,
            directoryURL: logDirectoryURL
        )
    }

    mutating func protectCompletedOutput() {
        shouldDeleteOutputOnCancel = false
    }
}
