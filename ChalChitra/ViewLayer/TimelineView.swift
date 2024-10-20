//
//  TimelineView.swift
//  ChalChitra
//
//  Created by Kunal Kamble on 14/10/24.
//

import AVFoundation
import UIKit

class TimelineView: UIView {
    // MARK: - Properties

    private lazy var currentTimeLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var durationLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .bar)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(currentTimeLabel)
        addSubview(durationLabel)
        addSubview(progressView)

        progressView.horizontalToSuperview(usingSafeArea: true)
        progressView.height(20)
        progressView.topToSuperview()
        currentTimeLabel.topToBottom(of: progressView)
        currentTimeLabel.leftToSuperview(usingSafeArea: true)
        durationLabel.topToBottom(of: progressView)
        durationLabel.rightToSuperview(usingSafeArea: true)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    func configure(currentTime: CMTime, durationTime: CMTime) {
        currentTimeLabel.text = currentTime.positionalTime
        durationLabel.text = durationTime.positionalTime
        progressView.progress = Float(currentTime.seconds) / Float(durationTime.seconds)
    }
}
