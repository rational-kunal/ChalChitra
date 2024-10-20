//
//  ChalChitra.swift
//  ChalChitra
//
//  Created by Kunal Kamble on 14/10/24.
//

import AVFoundation
import OSLog
import UIKit

class ChalChitra: UIView {

    // MARK: - Properties

    private let url: URL
    private var timelineTimer: Timer?

    // MARK: - Views

    private lazy var timelineView = TimelineView(frame: .zero)

    private lazy var playerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()

    lazy var hlsManager = {
        let manager = HLSManager(m3u8Url: url)
        manager.delegate = self
        return manager
    }()

    // MARK: - Init

    init(url: URL, playerHeight: Double? = .zero) {
        self.url = url

        super.init(frame: .zero)

        addSubview(playerView)
        playerView.layer.addSublayer(hlsManager.displayLayer)

        addSubview(timelineView)

        timelineView.topToBottom(of: playerView)
        timelineView.widthToSuperview(usingSafeArea: true)

        if let playerHeight {
            playerView.edgesToSuperview(excluding: .bottom)
            playerView.height(playerHeight)
        } else {
            playerView.edgesToSuperview()
        }

        setUpHLSManager()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Overrides

    override func layoutSubviews() {
        super.layoutSubviews()
        hlsManager.displayLayer.frame = playerView.bounds
        Logger.ChalChitra.info("Display layer bounds set to \(self.hlsManager.displayLayer.bounds.debugDescription)")
    }

    // MARK: - Private

    private func setUpHLSManager() {
        Task { [weak self] in
            await self?.hlsManager.load()
            self?.startTimelineTimer()
        }
    }
}

// MARK: - HLSManagerDelegate

extension ChalChitra: HLSManagerDelegate {
    func hlsManagerDidFetchM3U8() {
        // Update total duration first
    }
}

// MARK: - Timeline Related

extension ChalChitra {
    func startTimelineTimer() {
        stopTimelineUpdates()
        startTimelineUpdates()
    }

    func startTimelineUpdates() {
        timelineTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateTimelineView()
        }
    }

    func updateTimelineView() {
        timelineView.configure(currentTime: hlsManager.currentTime, durationTime: hlsManager.totalDuration)
    }

    func stopTimelineUpdates() {
        timelineTimer?.invalidate()
        timelineTimer = nil
    }
}
