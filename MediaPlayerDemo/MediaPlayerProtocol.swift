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

extension Notification.Name {
    static let SJMediaPlayerViewReadyForDisplayNotification = Notification.Name("SJMediaPlayerViewReadyForDisplayNotification")
}

protocol MediaPlayerProtocol {
    
    typealias CompletionHandler = (_ finished: Bool)->()
    
    var presentationSize: CGSize? { get }
    var playView: UIView? { get }
    var assetStatus: AssetStatus { get }
    /// 是否调用过`replay`
    var isReplayed: Bool { get }
    
    /// 是否调用过`play`方法
    var isPlayed: Bool { get }
    
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
    var duration: TimeInterval { get }
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
        self.layer .removeObserver(self, forKeyPath: AVMediaPlayerLayerView.kReadyForDisplay)
    }
}

class AVMediaPlayer: MediaPlayerProtocol {
    
    private var _avPlayer: AVPlayer!
    private var _playView: AVMediaPlayerLayerView?
    var presentationSize: CGSize? {
        _avPlayer.currentItem?.presentationSize
    }
    
    var playView: UIView? {
        _playView
    }
    var assetStatus: AssetStatus = .unknown
    
    var isReplayed: Bool = false
    
    var isPlayed: Bool = false
    
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
    }
    
    func seekToTime(_ time: CMTime, completionHandler: CompletionHandler?) {
        
    }
    
    var currentTime: TimeInterval {
        0
    }
    
    var duration: TimeInterval {
        0
    }
    
    var playableDuration: TimeInterval {
        0
    }
    
    func play() {
        _avPlayer.play()
    }
    
    func pause() {
        
    }
    
    func replay() {
        
    }
    
}


