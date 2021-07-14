//
//  PeriodicTimeObserverItem.swift
//  MediaPlayerDemo
//
//  Created by Shafujiu on 2021/7/14.
//

import Foundation

class MediaPlayerPeriodicTimeObserverItem {
    typealias TimeChangedBlock = (_ time: TimeInterval)->()
    
    private var interval: TimeInterval
    private weak var player: MediaPlayerProtocol?
    private var currentTimeDidChangeExeBlock: TimeChangedBlock?
    private var playableDurationDidChangeExeBlock: TimeChangedBlock?
    private var durationDidChangeExeBlock: TimeChangedBlock?
    
    private var timer: Timer?
    private var currentTime: TimeInterval?
    
    init(interval: TimeInterval, player: MediaPlayerProtocol, currentTimeDidChangeExeBlock: TimeChangedBlock?,
         playableDurationDidChangeExeBlock: TimeChangedBlock?,
         durationDidChangeExeBlock:TimeChangedBlock?) {
        self.interval = interval
        self.player = player
        
        self.currentTimeDidChangeExeBlock = currentTimeDidChangeExeBlock
        self.playableDurationDidChangeExeBlock = playableDurationDidChangeExeBlock
        self.durationDidChangeExeBlock = durationDidChangeExeBlock
        
        self.resumeOrPause()
        
        NotificationCenter.default.addObserver(self, selector: #selector(resumeOrPause), name: .SJMediaPlayerTimeControlStatusDidChangeNotification, object: player)
        NotificationCenter.default.addObserver(self, selector: #selector(durationDidChange), name: .SJMediaPlayerDurationDidChangeNotification, object: player)
        NotificationCenter.default.addObserver(self, selector: #selector(playableDurationDidChange), name: .SJMediaPlayerPlayableDurationDidChangeNotification, object: player)
    }
    
    
    deinit {
        print("MediaPlayerTimeObserverItem deinit")
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func durationDidChange() {
        guard let durantion = player?.duration else {return}
        durationDidChangeExeBlock?(durantion)
    }
    
    @objc private func playableDurationDidChange() {
        guard let playableDuration = player?.playableDuration else {return}
        playableDurationDidChangeExeBlock?(playableDuration)
    }
    
    @objc private func resumeOrPause() {
        if player?.timeControlStatus == .paused {
            self.invalidate()
        } else if (timer == nil) {
            timer = Timer(timeInterval: interval, target: self, selector: #selector(timeAction(_:)), userInfo: nil, repeats: true)
            timer?.fireDate = Date(timeIntervalSinceNow: interval)
            RunLoop.main.add(timer!, forMode: .common)
        }
    }
    
    @objc private func timeAction(_ timer: Timer) {
        _refresh()
    }
    
    func stop() {
        self.invalidate()
        playableDurationDidChangeExeBlock?(0)
        currentTimeDidChangeExeBlock?(0)
        durationDidChangeExeBlock?(0)
    }
    
    private func _refresh() {
        guard let currentTime = player?.currentTime else { return }
        if self.currentTime != currentTime {
            self.currentTime = currentTime
            currentTimeDidChangeExeBlock?(currentTime)
        }
    }
}
