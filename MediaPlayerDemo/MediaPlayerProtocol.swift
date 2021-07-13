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
    static let SJMediaPlayerAssetStatusDidChangeNotification = Notification.Name("SJMediaPlayerAssetStatusDidChangeNotification")
    static let SJMediaPlayerTimeControlStatusDidChangeNotification = Notification.Name("SJMediaPlayerTimeControlStatusDidChangeNotification")
    static let SJMediaPlayerPresentationSizeDidChangeNotification = Notification.Name("SJMediaPlayerPresentationSizeDidChangeNotification")
    static let SJMediaPlayerPlaybackDidFinishNotification = Notification.Name("SJMediaPlayerPlaybackDidFinishNotification")
    static let SJMediaPlayerDidReplayNotification = Notification.Name("SJMediaPlayerDidReplayNotification")
    static let SJMediaPlayerDurationDidChangeNotification = Notification.Name("SJMediaPlayerDurationDidChangeNotification")
    static let SJMediaPlayerPlayableDurationDidChangeNotification = Notification.Name("SJMediaPlayerPlayableDurationDidChangeNotification")
    static let SJMediaPlayerViewReadyForDisplayNotification = Notification.Name("SJMediaPlayerViewReadyForDisplayNotification")
}

protocol MediaPlayerDelegate: AnyObject {
    /// 资源状态改变回调
    func mediaPlayer(_ player: MediaPlayerProtocol, assetStatusDidChange status: AssetStatus)
    /// 时间控制状态
    func mediaPlayer(_ player: MediaPlayerProtocol, timeControlStatusDidChange status: PlaybackTimeControlStatus)
    /// 显示的视图的大小
    func mediaPlayer(_ player: MediaPlayerProtocol, presentationSizeDidChange size: CGSize)
    /// 播放完成
    func mediaPlayerPlaybackDidFinish(_ player: MediaPlayerProtocol)
    /// 总时长变化
    func mediaPlayer(_ player: MediaPlayerProtocol, durationDidChange duration: TimeInterval)
    /// 预加载时长变化
    func mediaPlayer(_ player: MediaPlayerProtocol, playableDurationDidChange duration: TimeInterval)
    /// 可以渲染View
    func mediaPlayerReadyForDisplay(_ player: MediaPlayerProtocol)
    /// 进度回调
    func mediaPlayer(_ player: MediaPlayerProtocol, currentTimeDidChange time: TimeInterval)
    
    func mediaPlayer(_ player: MediaPlayerProtocol, willSeekTo time: CMTime)
}

protocol MediaPlayerProtocol: AnyObject {
    
    typealias CompletionHandler = (_ finished: Bool)->()
    
    /// 调用进度的回调的时间
    var periodicTimeInterval: TimeInterval { get set }
    
    /// 播放器相关的回调
    var deleagte: MediaPlayerDelegate? { get set }
    
    var presentationSize: CGSize? { get }
    
    var playView: UIView? { get }
    
    var timeControlStatus: PlaybackTimeControlStatus { get }
    
    var assetStatus: AssetStatus { get }
    
    /// 播放失败的时候  返回
    var error: Error? { get }
    
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
    var playableDuration: TimeInterval? { get }
    
    func play()
    func pause()
    func replay()

}

protocol MediaPlayerViewProtocol {

    var videoGravity: AVLayerVideoGravity { get set }
    var readyForDisplay: Bool { get }
}
