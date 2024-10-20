//
//  M3U8MetadataService.swift
//  ChalChitra
//
//  Created by Kunal Kamble on 15/10/24.
//

import AVFoundation
import M3U8Kit
import OSLog

// ASSUMPTION: The given URL is master m3u8 containing multiple m3u8 for each resolution
class M3U8MetadataService {
    private let masterURL: URL
    private var firstStreamSegmentURLs: [URL]?

    private init(m3u8URL: URL) {
        // TODO: Add assert to check M3U8 URL
        masterURL = m3u8URL
    }

    static func makeService(forM3U8URLString m3u8URL: URL) async -> M3U8MetadataService {
        // TODO: Add assert to check M3U8 URL
        let service = M3U8MetadataService(m3u8URL: m3u8URL)
        await service.load()
        return service
    }

    func load() async {
        // TODO: Do this in background

        Logger.M3U8MetadataService.info("Loading \(self.masterURL.absoluteString)")
        do {
            try await _load()
        } catch {
            Logger.M3U8MetadataService.error("Unable to load \(self.masterURL.absoluteString) with error: \(error)")
        }
    }

    var _totalDurationInSeconds: Double?
    lazy var totalDuration: CMTime = {
        guard let _totalDurationInSeconds else {
            Logger.M3U8MetadataService.error("No duration")
            return .zero
        }

        let timescale: CMTimeScale = 1000 // You can choose a timescale (e.g., 1000 for milliseconds precision)
        let duration = CMTime(seconds: _totalDurationInSeconds, preferredTimescale: timescale)
        return duration
    }()

    var segmentsCount: Int {
        guard let firstStreamSegmentURLs else {
            Logger.M3U8MetadataService.error("No firstStreamSegmentURLs")
            return 0
        }

        return firstStreamSegmentURLs.count
    }

    func segmentURL(at index: Int) -> URL? {
        guard let firstStreamSegmentURLs else {
            Logger.M3U8MetadataService.error("No firstStreamSegmentURLs")
            return nil
        }

        return firstStreamSegmentURLs[index]
    }

    // MARK: - Private

    private func _load() async throws {
        guard let masterModel = try await (masterURL as NSURL).m3u_loadAsyncCompletion() else {
            Logger.M3U8MetadataService.error("Unable to parse master m3u8 \(self.masterURL.absoluteString)")
            return
        }

        // FIXME: Update to fetch data from all stream (and then required stream)
        guard let firstStreamM3U8URL = masterModel.masterPlaylist.xStreamList.firstStreamInf().m3u8URL() as? NSURL else {
            Logger.M3U8MetadataService.error("Unable to get the first stream m3u8 url for \(self.masterURL.absoluteString)")
            return
        }

        Logger.M3U8MetadataService.info("Loading first stream m3u8 \(firstStreamM3U8URL.absoluteString ?? "<>")")
        guard let firstStreamModel = try await (firstStreamM3U8URL as NSURL).m3u_loadAsyncCompletion() else {
            Logger.M3U8MetadataService.error("Unable to parse stream m3u8")
            return
        }

        guard let firstStreamBaseURL = firstStreamM3U8URL.deletingLastPathComponent as? NSURL,
              let firstStreamSegmentList = firstStreamModel.mainMediaPl.segmentList
        else {
            return
        }

        var segmentURLs = [URL]()
        var totalDurationInSeconds = 0.0
        for i in 0 ..< firstStreamSegmentList.count {
            // Should we use relative string ?
            if let segmentURL = firstStreamBaseURL.appendingPathComponent(firstStreamSegmentList.segmentInfo(at: i).uri.absoluteString) {
                segmentURLs.append(segmentURL)
            }

            totalDurationInSeconds += firstStreamSegmentList.segmentInfo(at: i).duration
        }
        _totalDurationInSeconds = totalDurationInSeconds
        Logger.M3U8MetadataService.info("\(segmentURLs.count) segments loaded for \(firstStreamM3U8URL.absoluteString ?? "<>") (\(self.masterURL.absoluteString))")
        self.firstStreamSegmentURLs = segmentURLs
    }
}
