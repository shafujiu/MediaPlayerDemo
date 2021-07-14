////
////  IJKMediaPlayer.swift
////  MediaPlayerDemo
////
////  Created by Shafujiu on 2021/7/14.
////
//
//import UIKit
//
//
//class IJKMediaPlayer: IJKFFMoviePlayerController, MediaPlayerProtocol {
//    var periodicTimeInterval: TimeInterval
//    
//    var delegate: MediaPlayerDelegate?
//    
//    var presentationSize: CGSize?
//    
//    var playView: UIView?
//    
//    var timeControlStatus: MediaTimeControlStatus
//    
//    var assetStatus: AssetStatus
//    
//    var error: Error?
//    
//    var isPlaybackFinished: Bool
//    
//    var volume: Float
//    
//    var muted: Bool
//    
//    func seekToTime(_ time: TimeInterval, completionHandler: CompletionHandler?) {
//        
//    }
//    
//    var currentTime: TimeInterval
//    
//    
//    
//    
//    
//    func replay() {
//        
//    }
//    
//
//    init(url: URL, options: IJKFFOptions) {
//        periodicTimeInterval = 0.5
//        isPlaybackFinished = false
//        timeControlStatus = .paused
//        assetStatus = .unknown
//        volume = 1
//        muted = false
//        currentTime = 0
//        
//        
//        super.init(contentURL: url, with: options)
//    }
//    
//
//}
