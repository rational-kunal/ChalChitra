//
//  MP4ToSampleBufferConverter.swift
//  ChalChitra
//
//  Created by Kunal Kamble on 18/10/24.
//

import OSLog
import ffmpegkit
import M3U8Kit
import AVFoundation

class MP4ToSampleBufferConverter {
    var assetReader: AVAssetReader?
    var videoTrackOutput: AVAssetReaderTrackOutput?
    
    var previousFrameTime = CMTime.zero
    var previousActualFrameTime = CFAbsoluteTimeGetCurrent()

    var onSampleBuffer: ((CMSampleBuffer) -> Void)?
    
    func loadMP4(url: URL) {
        let asset = AVAsset(url: url)
        
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            assertionFailure("Error creating AVAssetReader: \(error)")
            return
        }
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            assertionFailure("No video track found in asset.")
            return
        }
        
        let videoSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA // 32-bit BGRA format
        ]
        
        videoTrackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoSettings)
        if let videoTrackOutput = videoTrackOutput {
            assetReader?.add(videoTrackOutput)
        }
        
        // Start reading
        assetReader?.startReading()
        
        // Start reading frames
        readVideoFrames()
    }
    
    // Function to read video frames and get CMSampleBuffer
    func readVideoFrames() {
        guard let reader = assetReader, let trackOutput = videoTrackOutput else {
            return
        }
        
        // Keep reading until the asset reader is done
        while reader.status == .reading {
            if let sampleBuffer = trackOutput.copyNextSampleBuffer() {
                // Process the CMSampleBuffer here
                processSampleBuffer(sampleBuffer)
            }
        }
        
        if reader.status == .completed {
            print("Finished reading the video file.")
        } else if reader.status == .failed {
            print("Failed to read the video file: \(reader.error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    // Function to process each CMSampleBuffer
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Here you have access to each video frame as a CMSampleBuffer
        // You can pass it to a display layer, save it, or process it further
        let currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(
            sampleBuffer)
        let differenceFromLastFrame = CMTimeSubtract(
            currentSampleTime, previousFrameTime)
        let currentActualTime = CFAbsoluteTimeGetCurrent()
        
        let frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame)
        let actualTimeDifference = currentActualTime - previousActualFrameTime
        
        if frameTimeDifference > actualTimeDifference {
            usleep(
                UInt32(round(1000000.0 * (frameTimeDifference - actualTimeDifference))))
        }
        
        previousFrameTime = currentSampleTime
        previousActualFrameTime = CFAbsoluteTimeGetCurrent()
        
        setSampleBufferAttachments(sampleBuffer)

        if let onSampleBuffer {
            onSampleBuffer(sampleBuffer)
        } else {
            Logger.MP4ToSampleBufferConverter.info("onSampleBuffer is nil")
        }
    }

    func setSampleBufferAttachments(_ sampleBuffer: CMSampleBuffer) {
        let attachments: CFArray! = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true)
        let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
                                       to: CFMutableDictionary.self)
        let key = Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque()
        let value = Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
        CFDictionarySetValue(dictionary, key, value)
    }
}
