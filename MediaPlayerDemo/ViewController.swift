//
//  ViewController.swift
//  MediaPlayerDemo
//
//  Created by Shafujiu on 2021/7/12.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var playView: UIView!
    
    var player: AVMediaPlayer?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let url = "https://xy2.v.netease.com/r/video/20190110/bea8e70d-ffc0-4433-b250-0393cff10b75.mp4"
        let player = AVMediaPlayer(url: URL(string: url)!)
        self.player = player
        player.playView?.frame = playView.bounds
        playView.addSubview(player.playView!)
        player.play()
    }

    deinit {
        print( "ViewController", #function )
    }
}

