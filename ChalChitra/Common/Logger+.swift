//
//  Logger+.swift
//  ChalChitra
//
//  Created by Kunal Kamble on 20/10/24.
//

import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    static let M3U8MetadataService = Logger(subsystem: subsystem, category: "M3U8MetadataService")
    static let ChalChitra = Logger(subsystem: subsystem, category: "ChalChitra")
    static let ChalChitraDebug = Logger(subsystem: subsystem, category: "ChalChitraDebug")
    static let HLSManager = Logger(subsystem: subsystem, category: "HLSManager")
    static let MP4ToSampleBufferConverter = Logger(subsystem: subsystem, category: "MP4ToSampleBufferConverter")
}
