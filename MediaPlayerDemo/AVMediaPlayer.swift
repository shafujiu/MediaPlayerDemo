//
//  MediaPlayerViewProtocol.swift
//  MediaPlayerDemo
//
//  Created by Shafujiu on 2021/7/12.
//

import UIKit
import AVFoundation


struct MediaSeekingInfo {
    var isSeeking: Bool
    var time: CMTime
}

class AVMediaPlayer: NSObject, MediaPlayerProtocol {
    
    private var _avPlayer: AVPlayer!
    private var _playView: AVMediaPlayerLayerView?
    
    // 取进度回调
    private var periodicTimeObserver: MediaPlayerPeriodicTimeObserverItem?
    private var minBufferedDuration: TimeInterval?
    private var innerError: Error?
    private var seekingInfo: MediaSeekingInfo = MediaSeekingInfo(isSeeking: false, time: .zero)
    
    private var playerItemStatusOb: NSKeyValueObservation?
    private var playItemPlaybackLikelyToKeepUpOb: NSKeyValueObservation?
    private var playItemPlaybackBufferEmptyOb: NSKeyValueObservation?
    private var playItemPlaybackBufferFullOb: NSKeyValueObservation?
    private var playItemLoadedTimeRangesOb: NSKeyValueObservation?
    private var playItemPresentationSizeOb: NSKeyValueObservation?
    private var avPlayerStatusOb: NSKeyValueObservation?
    private var avPlayertimeControlStatusOb: NSKeyValueObservation?
    
    weak var delegate: MediaPlayerDelegate?
    
    var periodicTimeInterval: TimeInterval = 0.5 {
        didSet {
            _removePeriodicTimeObserver()
            _addPeriodicTimeObserver()
        }
    }
    
    var error: Error? {
        if innerError != nil {
            return innerError
        }
        if _avPlayer.currentItem?.error != nil {
            return _avPlayer.currentItem?.error
        }
        if _avPlayer.error != nil {
            return _avPlayer.error
        }
        return nil
    }
    
    var presentationSize: CGSize? {
        _avPlayer.currentItem?.presentationSize
    }
    
    var playView: UIView? {
        _playView
    }
    
    private(set) var timeControlStatus: MediaTimeControlStatus {
        didSet {
            self._postNotification(.SJMediaPlayerTimeControlStatusDidChangeNotification)
            self.delegate?.mediaPlayer(self, timeControlStatusDidChange: timeControlStatus)
        }
    }
    
    var assetStatus: AssetStatus = .unknown {
        didSet {
            self._postNotification(.SJMediaPlayerAssetStatusDidChangeNotification)
            self.delegate?.mediaPlayer(self, assetStatusDidChange: assetStatus)
        }
    }
    
    private(set) var isReplayed: Bool = false
    
    private(set) var isPlayed: Bool = false
    
    private(set) var isPlaybackFinished: Bool {
        didSet {
            if isPlaybackFinished {
                self._postNotification(.SJMediaPlayerPlaybackDidFinishNotification)
                self.delegate?.mediaPlayerPlaybackDidFinish(self)
                
            }
        }
    }
    var volume: Float {
        set {
            _avPlayer.volume = newValue
        }
        get {
            _avPlayer.volume
        }
    }
    
    var muted: Bool {
        set {
            _avPlayer.isMuted = newValue
        }
        get {
            _avPlayer.isMuted
        }
    }
    
    init(url: URL) {
        _avPlayer = AVPlayer(playerItem: AVPlayerItem(url: url))
        
        isPlaybackFinished = false
        timeControlStatus = .paused
        
        super.init()
        let layerView = AVMediaPlayerLayerView()
        layerView.layer.player = _avPlayer
        layerView.readyForDisplayHandler = { [weak self] in
            guard let self = self else {return}
            self.delegate?.mediaPlayerReadyForDisplay(self)
        }
        _playView = layerView
        _addPeriodicTimeObserver()
        _prepareToPlay()
    }
    
    deinit {
        print("AVMediaPlayer deinit")
        _removePeriodicTimeObserver()
        
        NotificationCenter.default.removeObserver(self)
    }
    
    func seekToTime(_ time: TimeInterval, completionHandler: CompletionHandler?) {
        let tolerance = CMTime.positiveInfinity
        var targetTime = time
        let dur = duration ?? 0
        if time > dur {
            targetTime = dur * 0.98
        } else if time < 0 {
            targetTime = 0
        }
        let seekTime = CMTime(seconds: targetTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        seekToTime(time: seekTime, toleranceBefore: tolerance, toleranceAfter: tolerance, completionHandler: completionHandler)
    }
    
    var currentTime: TimeInterval {
        if isPlaybackFinished {
            return duration ?? 0
        } else {
            return CMTimeGetSeconds(_avPlayer.currentTime())
        }
    }
    
    private(set) var duration: TimeInterval? {
        didSet {
            self._postNotification(.SJMediaPlayerDurationDidChangeNotification)
            guard let dur = duration else {return}
            self.delegate?.mediaPlayer(self, durationDidChange: dur)
        }
    }
    
    private(set) var playableDuration: TimeInterval? {
        didSet {
            self._postNotification(.SJMediaPlayerPlayableDurationDidChangeNotification)
            guard let ableDur = playableDuration else {return}
            self.delegate?.mediaPlayer(self, playableDurationDidChange: ableDur)
        }
    }
    
    func play() {
        if assetStatus == .failed {
            return
        }
        if self.isPlaybackFinished {
            self.replay()
            return
        }
        
        isPlayed = true
        
        if timeControlStatus == .paused {
            timeControlStatus = .waitingToPlay
        }
        _avPlayer.play()
        _toEvaluating()
    }
    
    func pause() {
        self.timeControlStatus = .paused
        _avPlayer.pause()
    }
    
    func replay() {
        if self.assetStatus == .failed {
            return
        }
        
        isReplayed = true
        
        if timeControlStatus == .paused {
            timeControlStatus = .waitingToPlay
        }
        
        self.seekToTime(.zero) { [weak self] finished in
            
            self?._postNotification(.SJMediaPlayerDidReplayNotification)
            self?.play()
        }
    }
    
}

// Mark: - private api
private extension AVMediaPlayer {
    
    func _removePeriodicTimeObserver() {
        periodicTimeObserver?.invalidate()
        periodicTimeObserver = nil
    }
    
    /// 周期性 回调进度
    func _addPeriodicTimeObserver() {
        periodicTimeObserver = MediaPlayerPeriodicTimeObserverItem(interval: periodicTimeInterval, player: self, currentTimeDidChangeExeBlock: { [weak self] time in
            print("currentTimeDidChangeExeBlock time =", time)
            guard let self = self else {return}
            self.delegate?.mediaPlayer(self, currentTimeDidChange: time)
        }, playableDurationDidChangeExeBlock: { time in
            
        }, durationDidChangeExeBlock: { time in
            
        })
    }
    
    func _postNotification(_ name: Notification.Name) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: self)
        }
    }
    
    func _prepareToPlay() {
        let playItem = _avPlayer.currentItem
        playItem?.asset.loadValuesAsynchronously(forKeys: ["duration"], completionHandler: { [weak self] in
            guard let self = self else {return}
            self._updateDuration()
        })
        
        addObservers(for: playItem)
        
        addAVPlayerObserver()
        
        NotificationCenter.default.addObserver(self, selector: #selector(failedToPlayToEndTime(note:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playItem)
        NotificationCenter.default.addObserver(self, selector: #selector(didPlayToEndTime(note:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playItem)
        NotificationCenter.default.addObserver(self, selector: #selector(newAccessLogEntry(note:)), name: NSNotification.Name.AVPlayerItemNewAccessLogEntry, object: playItem)
        
        self._toEvaluating()
    }
    
    private func addAVPlayerObserver() {
        avPlayerStatusOb = _avPlayer.observe(\.status, options: [.new], changeHandler: {[weak self] avp, change in
            print("avPlayerStatusOb change new", avp.status.rawValue)
            self?._toEvaluating()
        })
        if #available(iOS 10.0, *) {
            avPlayertimeControlStatusOb = _avPlayer.observe(\AVPlayer.timeControlStatus, options: [.new], changeHandler: {[weak self] avp, change in
                print("avPlayertimeControlStatusOb change new", avp.timeControlStatus.rawValue)
                
                self?._toEvaluating()
                guard let self = self else {return}
                switch self._avPlayer.timeControlStatus {
                case .paused:
                    print("AVPlayer.TimeControlStatus.Paused\n");
                case .waitingToPlayAtSpecifiedRate:
                    if ( self._avPlayer.reasonForWaitingToPlay == AVPlayer.WaitingReason.toMinimizeStalls ) {
                        print("AVPlayer.TimeControlStatus.WaitingToPlay(Reason: WaitingToMinimizeStallsReason)\n")
                    }
                    else if ( self._avPlayer.reasonForWaitingToPlay == AVPlayer.WaitingReason.noItemToPlay ) {
                        print("AVPlayer.TimeControlStatus.WaitingToPlay(Reason: WaitingWithNoItemToPlayReason)\n")
                    }
                    else if ( self._avPlayer.reasonForWaitingToPlay == AVPlayer.WaitingReason.evaluatingBufferingRate ) {
                        print("AVPlayer.TimeControlStatus.WaitingToPlay(Reason: WhileEvaluatingBufferingRateReason)\n")
                    }
                    
                    print(self.error)
                case .playing:
                    print("AVPlayer.TimeControlStatus.Playing\n")
                @unknown default:
                    break
                }
            })
        }
    }
    
    private func addObservers(for item: AVPlayerItem?) {
        
        /// 资源状态
        playerItemStatusOb = item?.observe(\.status, options: [.new], changeHandler: { [weak self] _, change in
            print("playerItemStatusOb change new ", change.newValue ?? "")
            self?._toEvaluating()
        })
        /// 缓存是否足够播放
        playItemPlaybackLikelyToKeepUpOb = item?.observe(\.isPlaybackLikelyToKeepUp, options: [.new], changeHandler: { [weak self] _, change in
            print("playItemPlaybackLikelyToKeepUpOb change new", change.newValue ?? "")
            self?._toEvaluating()
        })
        
        playItemPlaybackBufferEmptyOb = item?.observe(\.isPlaybackBufferEmpty, options: [.new], changeHandler: { [weak self] _, change in
            print("playItemPlaybackBufferEmptyOb change new", change.newValue ?? "")
            self?._toEvaluating()
        })
        
        playItemPlaybackBufferFullOb = item?.observe(\.isPlaybackBufferFull, options: [.new], changeHandler: { [weak self] _, change in
            print("playItemPlaybackBufferFullOb change new", change.newValue ?? "")
            self?._toEvaluating()
        })
        
        playItemLoadedTimeRangesOb = item?.observe(\.loadedTimeRanges, options: [.new], changeHandler: { [weak self] _, change in
//            print("playItemLoadedTimeRangesOb change new", change.newValue ?? "")
            self?._loadedTimeRangesDidChange()
        })
        
        playItemPresentationSizeOb = item?.observe(\.presentationSize, options: [.new], changeHandler: { [weak self] _, change in
            print("playItemPresentationSizeOb change new", change.newValue ?? "")
            guard let self = self, let size = change.newValue else {return}
            self._postNotification(.SJMediaPlayerPresentationSizeDidChangeNotification)
            self.delegate?.mediaPlayer(self, presentationSizeDidChange: size)
        })
        
    }
    
    @objc private func failedToPlayToEndTime(note: Notification) {
        let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey]
        DispatchQueue.main.async {
            self.innerError = err as? Error
        }
    }
    
    @objc private func didPlayToEndTime(note: Notification) {
        DispatchQueue.main.async {
            self.isPlaybackFinished = true
            self.pause()
        }
    }
    
    @objc private func newAccessLogEntry(note: Notification) {
        _updatePlaybackType(note: note)
    }
    
    func _updateDuration() {
        DispatchQueue.main.async {
            guard let dur = self._avPlayer.currentItem?.asset.duration else {return}
            let duration = CMTimeGetSeconds(dur)
            print("duration =", duration)
            self.duration = duration
        }
    }
    
    // FIXME: - 没有维护 播放原因的变量
    func _toEvaluating() {
        let playerItem = _avPlayer.currentItem
        
        DispatchQueue.main.async {
            var tempAssetStatus = self.assetStatus
            if playerItem?.status == .failed || self._avPlayer.status == .failed {
                tempAssetStatus = .failed
            } else if playerItem?.status == .readyToPlay && self._avPlayer.status == .readyToPlay {
                tempAssetStatus = .readyToPlay
            }
            
            if tempAssetStatus != self.assetStatus {
                self.assetStatus = tempAssetStatus
            }
            
            if tempAssetStatus == .failed {
                self.timeControlStatus = .paused
            }
            
            if #available(iOS 10.0, *) {
                let avt = self._avPlayer.timeControlStatus.playbackTimeControlStatus
                if self.timeControlStatus != avt {
                    self.timeControlStatus = avt
                }
            } else {
                if self.timeControlStatus == .paused {
                    self._avPlayer.pause()
                    return
                }
                var timeControlStatus = self.timeControlStatus
                if tempAssetStatus == .readyToPlay &&
                    (playerItem?.isPlaybackBufferFull == true ||
                        playerItem?.isPlaybackLikelyToKeepUp == true) {
                    timeControlStatus = .playing
                } else {
                    timeControlStatus = .waitingToPlay
                }
                if self.timeControlStatus != timeControlStatus {
                    self.timeControlStatus = timeControlStatus
                    if timeControlStatus == .playing {
                        self._avPlayer.play()
                    }
                }
            }
        }
    }
    
    func _willSeeking(_ time: CMTime) {
        _avPlayer.currentItem?.cancelPendingSeeks()
        seekingInfo.time = time
        seekingInfo.isSeeking = true
        self.isPlaybackFinished = false
    }
    
    func _didEndSeeking() {
        seekingInfo.time = .zero
        seekingInfo.isSeeking = false
    }
    
    func _updatePlaybackType(note: Notification) {
        
    }
    
    func _loadedTimeRangesDidChange() {
        
        guard let playerItem = _avPlayer.currentItem else {return}
        guard let range = playerItem.loadedTimeRanges.first?.timeRangeValue else { return }
        let playbaleDuration = CMTimeGetSeconds(CMTimeRangeGetEnd(range))
        DispatchQueue.main.async {
            self.playableDuration = playbaleDuration;
            
            if self.timeControlStatus == .waitingToPlay &&
                playerItem.isPlaybackBufferEmpty == false {
                let curTime = CMTimeGetSeconds(playerItem.currentTime())
                let playableMilli = playbaleDuration * 1000
                let curMilli = curTime * 1000
                let buffMilli = playableMilli - curMilli
                let maxBuffMilli = Double(self.minBufferedDuration ?? 8 * 1000)
                if  buffMilli > maxBuffMilli  {
                    self._playImmediately()
                }
                if  buffMilli < maxBuffMilli  {
                    print("SJAVMediaPlayer: 缓冲中...  进度: \t \(buffMilli) \t \(maxBuffMilli) \n");
                }
            }
        }
    }
    
    func _playImmediately() {
        if #available(iOS 10, *) {
            _avPlayer.playImmediately(atRate: 1)
        } else {
            self.play()
        }
        self._toEvaluating()
    }
    
    func seekToTime(time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: CompletionHandler?) {
        if _avPlayer.currentItem?.status != .readyToPlay {
            completionHandler?(false)
            return
        }
        
        self._willSeeking(time)
        
        self._avPlayer.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter, completionHandler: { [weak self] finished in
            self?._didEndSeeking()
            completionHandler?(finished)
        })
    }
}

@available(iOS 10.0, *)
extension AVPlayer.TimeControlStatus {
    var playbackTimeControlStatus: MediaTimeControlStatus {
        switch self {
        case .paused:
            return .paused
        case .waitingToPlayAtSpecifiedRate:
            return .waitingToPlay
        case .playing:
            return .playing
        @unknown default:
            return .paused
        }
    }
}
