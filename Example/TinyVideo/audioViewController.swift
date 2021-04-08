//
//  ViewController.swift
//  TinyAudio
//
//  Created by hao yin on 2021/3/26.
//

import UIKit
import TinyVideo
import AVKit
class audioViewController: UIViewController {

    let r = try! TinyAudioRecorder(audioStreamDescription: TinyAudioRecorder.PCMStream)
    let p = TinyAudioPlayer()
    let s = TinyAudioMemoryCache()
    var e = TinyAudioEncoder()
    var d = TinyAudioEncoder()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        // Do any additional setup after loading the view.
    
    }
    @IBAction func endRecord(_ sender: Any) {
        r.end()
        e.finish()
    }
    @IBAction func record(_ sender: Any) {
        
        try! AVAudioSession.sharedInstance().setCategory(.record)
        try! AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        e = TinyAudioEncoder()
        r.output = e
        e.output = s
//        e.bitRate = 64000

        r.start()
    }
    @IBAction func play(_ sender: Any) {
        try! AVAudioSession.sharedInstance().setCategory(.playback)
        try! AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        p.input = s
        p.start()
    }
    @IBAction func endPlay(_ sender: Any) {
        p.end()
    }
    deinit {
        r.end()
    }
}

