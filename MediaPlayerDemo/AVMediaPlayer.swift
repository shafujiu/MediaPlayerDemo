//
//  MediaPlayerViewProtocol.swift
//  MediaPlayerDemo
//
//  Created by Shafujiu on 2021/7/12.
//

import UIKit
import AVFoundation

class AVMediaPlayerLayerView: UIView, MediaPlayerViewProtocol {
    private static var kReadyForDisplay = "ReadyForDisplay"
    
    var videoGravity: AVLayerVideoGravity {
        set {
            layer.videoGravity = newValue
        }
        get {
            layer.videoGravity
        }
    }
    
    var readyForDisplay: Bool {
        layer.isReadyForDisplay
    }
    
    override var layer: AVPlayerLayer {
        get {
            super.layer as! AVPlayerLayer
        }
    }
    
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commentInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commentInit()
    }
    
    private func commentInit() {
        self.layer.addObserver(self, forKeyPath: AVMediaPlayerLayerView.kReadyForDisplay, options: .new, context: &AVMediaPlayerLayerView.kReadyForDisplay)
    }
    
    override class func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if context == &AVMediaPlayerLayerView.kReadyForDisplay {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .SJMediaPlayerViewReadyForDisplayNotification, object: self)
            }
        }
    }
    
    deinit {
        self.layer.removeObserver(self, forKeyPath: AVMediaPlayerLayerView.kReadyForDisplay)
    }
}

struct MediaSeekingInfo {
    var isSeeking: Bool
    var time: CMTime
}

class AVMediaPlayer: NSObject, MediaPlayerProtocol {
    
    private var _avPlayer: AVPlayer!
    private var _playView: AVMediaPlayerLayerView?
    private var refreshTimer: Timer?
    private var periodicTimeObserver: MediaPlayerTimeObserverItem?
    private var minBufferedDuration: TimeInterval?
    private var innerError: Error?
    private var seekingInfo: MediaSeekingInfo = MediaSeekingInfo(isSeeking: false, time: .zero)
    
    weak var deleagte: MediaPlayerDelegate?
    
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
    
    private(set) var timeControlStatus: PlaybackTimeControlStatus {
        didSet {
            self._refreshOrStop()
            self._postNotification(.SJMediaPlayerTimeControlStatusDidChangeNotification)
        }
    }
    
    var assetStatus: AssetStatus = .unknown {
        didSet {
            self._postNotification(.SJMediaPlayerAssetStatusDidChangeNotification)
        }
    }
    
    private(set) var isReplayed: Bool = false
    
    private(set) var isPlayed: Bool = false
    
    private(set) var isPlaybackFinished: Bool {
        didSet {
            if isPlaybackFinished {
                self._postNotification(.SJMediaPlayerPlaybackDidFinishNotification)
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
        _playView = AVMediaPlayerLayerView()
        _playView?.layer.player = _avPlayer
        
        isPlaybackFinished = false
        timeControlStatus = .paused
        
        super.init()
        
        _addPeriodicTimeObserver()
        _prepareToPlay()
    }
    
    
    deinit {
        print("AVMediaPlayer deinit")
        _removePeriodicTimeObserver()
        
        let playerItem = _avPlayer.currentItem
        playerItem?.removeObserver(self, forKeyPath: kStatus, context: &kStatus)
        playerItem?.removeObserver(self, forKeyPath: kPlaybackLikelyToKeepUp, context: &kPlaybackLikelyToKeepUp)
        playerItem?.removeObserver(self, forKeyPath: kPlaybackBufferEmpty, context: &kPlaybackBufferEmpty)
        playerItem?.removeObserver(self, forKeyPath: kPlaybackBufferFull, context: &kPlaybackBufferFull)
        playerItem?.removeObserver(self, forKeyPath: kLoadedTimeRanges, context: &kLoadedTimeRanges)
        playerItem?.removeObserver(self, forKeyPath: kPresentationSize, context: &kPresentationSize)
        
        _avPlayer.removeObserver(self, forKeyPath: kStatus, context: &kStatus)
        if #available(iOS 10.0, *) {
            _avPlayer.removeObserver(self, forKeyPath: kTimeControlStatus, context: &kTimeControlStatus)
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    func seekToTime(_ time: CMTime, completionHandler: CompletionHandler?) {
        let tolerance = CMTime.positiveInfinity
        seekToTime(time: time, toleranceBefore: tolerance, toleranceAfter: tolerance, completionHandler: completionHandler)
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
        }
    }
    
    private(set) var playableDuration: TimeInterval? {
        didSet {
            self._postNotification(.SJMediaPlayerPlayableDurationDidChangeNotification)
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
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if #available(iOS 10, *) {
            if context == &kTimeControlStatus  {
                
                switch _avPlayer.timeControlStatus {
                case .paused:
                    print("AVPlayer.TimeControlStatus.Paused\n");
                case .waitingToPlayAtSpecifiedRate:
                    if ( _avPlayer.reasonForWaitingToPlay == AVPlayer.WaitingReason.toMinimizeStalls ) {
                        print("AVPlayer.TimeControlStatus.WaitingToPlay(Reason: WaitingToMinimizeStallsReason)\n")
                    }
                    else if ( _avPlayer.reasonForWaitingToPlay == AVPlayer.WaitingReason.noItemToPlay ) {
                        print("AVPlayer.TimeControlStatus.WaitingToPlay(Reason: WaitingWithNoItemToPlayReason)\n")
                    }
                    else if ( _avPlayer.reasonForWaitingToPlay == AVPlayer.WaitingReason.evaluatingBufferingRate ) {
                        print("AVPlayer.TimeControlStatus.WaitingToPlay(Reason: WhileEvaluatingBufferingRateReason)\n")
                    }
                    
                    print(error)
                case .playing:
                    print("AVPlayer.TimeControlStatus.Playing\n")
                @unknown default:
                    break
                }
            }
        }
        
        if context == &kStatus ||
        context == &kPlaybackLikelyToKeepUp ||
        context == &kPlaybackBufferEmpty ||
        context == &kPlaybackBufferFull ||
        context == &kTimeControlStatus {
            self._toEvaluating()
        } else if context == &kLoadedTimeRanges {
            _loadedTimeRangesDidChange()
        } else if context == &kPresentationSize {
            _presentationSizeDidChange()
        }
    }
}



// Mark: - private api

fileprivate var kStatus = "status"
fileprivate var kPlaybackLikelyToKeepUp = "playbackLikelyToKeepUp"
fileprivate var kPlaybackBufferEmpty = "playbackBufferEmpty"
fileprivate var kPlaybackBufferFull = "playbackBufferFull"
fileprivate var kLoadedTimeRanges = "loadedTimeRanges"
fileprivate var kPresentationSize = "presentationSize"
fileprivate var kTimeControlStatus = "timeControlStatus"

private extension AVMediaPlayer {
    
    func _removePeriodicTimeObserver() {
        periodicTimeObserver?.invalidate()
        periodicTimeObserver = nil
    }
    
    /// 周期性 回调进度
    func _addPeriodicTimeObserver() {
        periodicTimeObserver = MediaPlayerTimeObserverItem(interval: periodicTimeInterval, player: self, currentTimeDidChangeExeBlock: { time in
            print("currentTimeDidChangeExeBlock time =", time)
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
        
        // 监听playItem 状态
        playItem?.addObserver(self, forKeyPath: kStatus, options: [.new], context: &kStatus)
        playItem?.addObserver(self, forKeyPath: kPlaybackLikelyToKeepUp, options: [.new], context: &kPlaybackLikelyToKeepUp)
        playItem?.addObserver(self, forKeyPath: kPlaybackBufferEmpty, options: [.new], context: &kPlaybackBufferEmpty)
        playItem?.addObserver(self, forKeyPath: kPlaybackBufferFull, options: [.new], context: &kPlaybackBufferFull)
        playItem?.addObserver(self, forKeyPath: kLoadedTimeRanges, options: [.new], context: &kLoadedTimeRanges)
        playItem?.addObserver(self, forKeyPath: kPresentationSize, options: [.new], context: &kPresentationSize)
        
        //
        _avPlayer.addObserver(self, forKeyPath: kStatus, options: [.new], context: &kStatus)
        if #available(iOS 10.0, *) {
            _avPlayer.addObserver(self, forKeyPath: kTimeControlStatus, options: [.new], context: &kTimeControlStatus)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(failedToPlayToEndTime(note:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playItem)
        NotificationCenter.default.addObserver(self, selector: #selector(didPlayToEndTime(note:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playItem)
        NotificationCenter.default.addObserver(self, selector: #selector(newAccessLogEntry(note:)), name: NSNotification.Name.AVPlayerItemNewAccessLogEntry, object: playItem)
        
        self._toEvaluating()
    }
    
    @objc private func failedToPlayToEndTime(note: Notification) {
        let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey]
        DispatchQueue.main.async {
            self.innerError = err as? Error
        }
    }
    
    @objc private func didPlayToEndTime(note: Notification) {
        _didPlayToEndTime(note)
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
    
    func _refreshOrStop() {
      
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
    
    func _didPlayToEndTime(_ note: Notification) {
        DispatchQueue.main.async {
//            self.finishedReason = SJFinishedReasonToEndTimePosition;
            self.isPlaybackFinished = true
            self.pause()
        }
    }
    
    func _updatePlaybackType(note: Notification) {
        
    }
    
    func _presentationSizeDidChange() {
        self._postNotification(.SJMediaPlayerPresentationSizeDidChangeNotification)
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

class MediaPlayerTimeObserverItem {
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


@available(iOS 10.0, *)
extension AVPlayer.TimeControlStatus {
    var playbackTimeControlStatus: PlaybackTimeControlStatus {
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
