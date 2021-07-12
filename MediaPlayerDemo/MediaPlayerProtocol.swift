//
//  MediaPlayerProtocol.swift
//  MediaPlayerDemo
//
//  Created by Shafujiu on 2021/7/12.
//

import UIKit
import AVFoundation

enum AssetStatus {
    case unknown
    case preparing
    case readyToPlay
    case failed
}

enum PlaybackTimeControlStatus {
    /// 暂停状态(已调用暂停或未执行任何操作的状态)
    case paused
    /// 播放状态(已调用播放), 当前正在缓冲或正在评估能否播放. 可以通过`reasonForWaitingToPlay`来获取原因, UI层可以根据原因来控制loading视图的状态.
    case waitingToPlay
    /// 播放状态(已调用播放), 当前播放器正在播放
    case playing
}

extension Notification.Name {
    static let SJMediaPlayerViewReadyForDisplayNotification = Notification.Name("SJMediaPlayerViewReadyForDisplayNotification")
    
    static let SJMediaPlayerDidReplayNotification = Notification.Name("SJMediaPlayerDidReplayNotification")
    
    static let SJMediaPlayerTimeControlStatusDidChangeNotification = Notification.Name("SJMediaPlayerTimeControlStatusDidChangeNotification")
    
    static let SJMediaPlayerDurationDidChangeNotification = Notification.Name("SJMediaPlayerDurationDidChangeNotification")
    
    static let SJMediaPlayerPlayableDurationDidChangeNotification = Notification.Name("SJMediaPlayerPlayableDurationDidChangeNotification")
}

protocol MediaPlayerProtocol: AnyObject {
    
    typealias CompletionHandler = (_ finished: Bool)->()
    
    var presentationSize: CGSize? { get }
    var playView: UIView? { get }
    var timeControlStatus: PlaybackTimeControlStatus { get }
    var assetStatus: AssetStatus { get }
    /// 是否调用过`replay`
    var isReplayed: Bool { get }
    
    /// 是否调用过`play`方法
    var isPlayed: Bool { get }
    
    /// 播放结束
    var isPlaybackFinished: Bool { get }
    /// 音量
    var volume: Float { get set }
    
    /// 是否静音
    var muted: Bool { get set }
    
    /// 选中某个时间
    /// - Parameters:
    ///   - time: time description
    ///   - completionHandler: 选中 回调
    func seekToTime(_ time: CMTime, completionHandler: CompletionHandler?)
    
    var currentTime: TimeInterval { get }
    var duration: TimeInterval? { get }
    var playableDuration: TimeInterval { get }
    
    func play()
    func pause()
    
    func replay()

}

protocol MediaPlayerViewProtocol {

    var videoGravity: AVLayerVideoGravity { get set }
    var readyForDisplay: Bool { get }
}

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

class AVMediaPlayer: MediaPlayerProtocol {
    
    private var _avPlayer: AVPlayer!
    private var _playView: AVMediaPlayerLayerView?
    private var refreshTimer: Timer?
    private var periodicTimeObserver: MediaPlayerTimeObserverItem?
    
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
    
    var assetStatus: AssetStatus = .unknown
    
    private(set) var isReplayed: Bool = false
    
    private(set) var isPlayed: Bool = false
    
    private(set) var isPlaybackFinished: Bool
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
        
        _addPeriodicTimeObserver()
        
        _prepareToPlay()
    }
    
    
    deinit {
        _removePeriodicTimeObserver()
    }
    
    func seekToTime(_ time: CMTime, completionHandler: CompletionHandler?) {
        
    }
    
    var currentTime: TimeInterval {
        0
    }
    
    private(set) var duration: TimeInterval? {
        didSet {
            self._postNotification(.SJMediaPlayerDurationDidChangeNotification)
        }
    }
    
    var playableDuration: TimeInterval {
        0
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
        periodicTimeObserver = MediaPlayerTimeObserverItem(interval: 0.5, player: self, currentTimeDidChangeExeBlock: { time in
            
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
        
        _avPlayer.currentItem?.asset.loadValuesAsynchronously(forKeys: ["duration"], completionHandler: { [weak self] in
            // FIXME: - self 提前释放了
            guard let self = self else {return}
            self._updateDuration()
        })
        
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
            let assetStatus = self.assetStatus
            if playerItem?.status == .failed || self._avPlayer.status == .failed {
                self.assetStatus = .failed
            } else if playerItem?.status == .readyToPlay && self._avPlayer.status == .readyToPlay {
                self.assetStatus = .readyToPlay
            }
            
            if assetStatus != self.assetStatus {
                self.assetStatus = assetStatus
            }
            
            if assetStatus == .failed {
                self.timeControlStatus = .paused
            }
            
            // 是否从某个位置开始播
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
                if assetStatus == .readyToPlay && (playerItem?.isPlaybackBufferFull == true || playerItem?.isPlaybackLikelyToKeepUp == true) {
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
        
        self.isPlaybackFinished = false
    }
    
    func _didPlayToEndTime(_ note: Notification) {
        DispatchQueue.main.async {
//            self.finishedReason = SJFinishedReasonToEndTimePosition;
            self.isPlaybackFinished = true
            self.pause()
        }
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
