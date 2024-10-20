//
//  HLSManager.swift
//  ChalChitra
//
//  Created by Kunal Kamble on 15/10/24.
//

import AVFoundation
import ffmpegkit
import Foundation
import OSLog

func convertTSFileToMP4(inputURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) {
    let inputPath = inputURL.absoluteString
    let outputPath = outputURL.path

    // FFmpeg command to convert .ts to .mp4
    let command = "-i \(inputPath) -c copy \(outputPath)"

    // Execute the command using FFmpegKit
    FFmpegKit.executeAsync(command) { session in
        let returnCode = session?.getReturnCode()

        if ReturnCode.isSuccess(returnCode) {
            print("Conversion successful!")
            completion(true)
        } else {
            print("Conversion failed with return code: \(String(describing: returnCode))")
            completion(false)
        }
    }
}

func processHLSSegment(inputTSURL: URL, completion: @escaping (URL?) -> Void) {
    // Define the output MP4 file URL (in the temp directory)
    let outputMP4URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")

    // Step 1: Convert .ts to .mp4 using FFmpegKit
    convertTSFileToMP4(inputURL: inputTSURL, outputURL: outputMP4URL) { success in
        if success {
            // Step 2: Extract CMSampleBuffer from the .mp4 file
            extractSampleBuffer(from: outputMP4URL) { _ in
                completion(outputMP4URL)
            }
        } else {
            print("TS to MP4 conversion failed.")
            completion(nil)
        }
    }
}

func extractSampleBuffer(from url: URL, completion: @escaping (CMSampleBuffer?) -> Void) {
    let asset = AVAsset(url: url)

    asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
        var error: NSError?
        let status = asset.statusOfValue(forKey: "tracks", error: &error)

        if status == .loaded {
            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                print("No video track found")
                completion(nil)
                return
            }

            do {
                let reader = try AVAssetReader(asset: asset)
                let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
                reader.add(output)

                reader.startReading()

                while let sampleBuffer = output.copyNextSampleBuffer() {
                    completion(sampleBuffer)
                    return
                }
            } catch {
                print("Error extracting samples: \(error)")
                completion(nil)
            }
        } else {
            print("Error loading tracks: \(String(describing: error))")
            completion(nil)
        }
    }
}

protocol HLSManagerDelegate: AnyObject {
    func hlsManagerDidFetchM3U8()
}

class HLSManager {
    // MARK: - Public vars

    weak var delegate: HLSManagerDelegate?

    var totalDuration: CMTime { m3u8MetadataService.totalDuration }

    var currentTime: CMTime {
        guard let timebase = displayLayer.controlTimebase else {
            Logger.HLSManager.error("Unable to get control timebase")
            return .zero
        }

        let currentTime = CMTimebaseGetTime(timebase)
        Logger.HLSManager.info("Current time: \(currentTime.seconds)")
        return currentTime
    }

    lazy var displayLayer: AVSampleBufferDisplayLayer = {
        let displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.videoGravity = .resizeAspect

        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)

        guard let timebase else {
            assertionFailure("No timebase")
            return displayLayer
        }

        CMTimebaseSetRate(timebase, rate: 1.0)
        displayLayer.controlTimebase = timebase

        return displayLayer
    }()

    // MARK: - Private vars

    private var m3u8Url: URL

    private var _m3u8MetadataService: M3U8MetadataService?
    private var m3u8MetadataService: M3U8MetadataService {
        assert(_m3u8MetadataService != nil)
        return _m3u8MetadataService!
    }

    lazy var mp4ToSampleBufferConverter: MP4ToSampleBufferConverter = {
        let converter = MP4ToSampleBufferConverter()
        converter.onSampleBuffer = { [weak self] sampleBuffer in
            if CMSampleBufferDataIsReady(sampleBuffer) {
                self?.displayLayer.enqueue(sampleBuffer)
            }
        }
        return converter
    }()

    // MARK: - Initlializer

    init(m3u8Url: URL) {
        self.m3u8Url = m3u8Url
    }

    // MARK: - methods

    func load() async {
        _m3u8MetadataService = await M3U8MetadataService.makeService(forM3U8URLString: m3u8Url)

        delegate?.hlsManagerDidFetchM3U8()

        // HACK: Process all segments recursively
        processSegmentRecursively(atIndex: 0, m3u8MetadataService: m3u8MetadataService)
    }
}

extension HLSManager {
    private func processSegmentRecursively(atIndex index: Int, m3u8MetadataService: M3U8MetadataService) {
        guard index < m3u8MetadataService.segmentsCount else { return }

        if let segmentURL = m3u8MetadataService.segmentURL(at: index) {
            processHLSSegment(inputTSURL: segmentURL) { [weak self] outURL in
                Logger.HLSManager.debug("[##] \(index) \(segmentURL.absoluteString) \(outURL?.absoluteString ?? "")")
                guard let outURL else { return }
//                    self?.converter.previousActualFrameTime = CFAbsoluteTimeGetCurrent()
//                    self?.converter.previousFrameTime = .zero
                self?.mp4ToSampleBufferConverter.loadMP4(url: outURL)

                // Move to the next segment after current one is processed
                self?.processSegmentRecursively(atIndex: index + 1, m3u8MetadataService: m3u8MetadataService)
            }
        } else {
            // Move to the next segment if current segmentURL is nil
            processSegmentRecursively(atIndex: index + 1, m3u8MetadataService: m3u8MetadataService)
        }
    }
}
