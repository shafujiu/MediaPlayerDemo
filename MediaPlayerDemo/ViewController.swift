//
//  ViewController.swift
//  MediaPlayerDemo
//
//  Created by Shafujiu on 2021/7/12.
//

import UIKit
import CoreMedia

class ViewController: UIViewController, MediaPlayerDelegate {
    func mediaPlayer(_ player: MediaPlayerProtocol, assetStatusDidChange status: AssetStatus) {
        print("AssetStatus = ", status)
    }
    
    func mediaPlayer(_ player: MediaPlayerProtocol, timeControlStatusDidChange status: MediaTimeControlStatus) {
        print("MediaTimeControlStatus = ", status)
    }
    
    func mediaPlayer(_ player: MediaPlayerProtocol, presentationSizeDidChange size: CGSize) {
        
    }
    
    func mediaPlayerPlaybackDidFinish(_ player: MediaPlayerProtocol) {
        
    }
    
    func mediaPlayer(_ player: MediaPlayerProtocol, durationDidChange duration: TimeInterval) {
        
    }
    
    func mediaPlayer(_ player: MediaPlayerProtocol, playableDurationDidChange duration: TimeInterval) {
        
    }
    
    func mediaPlayerReadyForDisplay(_ player: MediaPlayerProtocol) {
        
    }
    
    func mediaPlayer(_ player: MediaPlayerProtocol, currentTimeDidChange time: TimeInterval) {
        let progress = player.currentTime/(player.duration ?? 0)
        progressSlider.value = Float(progress)
    }
    

    @IBOutlet weak var playView: UIView!
    
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var progressSlider: UISlider!
    
    @IBAction func muteSwitch(_ sender: UISwitch) {
        player?.muted = !sender.isOn
    }
    
    
    @IBAction func progressSliderValueChange(_ sender: UISlider) {
        
        
        
//        CMTimeMakeWithSeconds
        let time = Double( sender.value) * (player?.duration ?? 0)
        player?.seekToTime( time, completionHandler: { _ in
            
        })
        
    }
    
    @IBAction func volumeSliderChange(_ sender: UISlider) {
        player?.volume = sender.value
    }
    
    var player: AVMediaPlayer?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let url = "https://xy2.v.netease.com/r/video/20190110/bea8e70d-ffc0-4433-b250-0393cff10b75.mp4"
        let player = AVMediaPlayer(url: URL(string: url)!)
        self.player = player
        player.playView?.frame = playView.bounds
        playView.addSubview(player.playView!)
        player.play()
//        player.delegate = self
    }

    deinit {
        print( "ViewController", #function )
    }
    
    @IBAction func play(_ sender: Any) {
        player?.play()
    }
    
    @IBAction func pause(_ sender: Any) {
        player?.pause()
    }
    @IBAction func replay(_ sender: Any) {
        player?.replay()
    }
}

