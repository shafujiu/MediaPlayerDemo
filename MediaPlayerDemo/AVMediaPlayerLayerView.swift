//
//  AVMediaPlayerLayerView.swift
//  MediaPlayerDemo
//
//  Created by Shafujiu on 2021/7/14.
//

import UIKit
import AVFoundation

class AVMediaPlayerLayerView: UIView, MediaPlayerViewProtocol {
    var readyForDisplayHandler: (() -> ())?
    private var readyForDisplayOb: NSKeyValueObservation?
    
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
        readyForDisplayOb = layer.observe(\.isReadyForDisplay, options: [.new], changeHandler: {[weak self] _, change in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .SJMediaPlayerViewReadyForDisplayNotification, object: self)
                self?.readyForDisplayHandler?()
            }
        })
    }
    
    deinit {
        print("AVMediaPlayerLayerView deinit")
    }
}
