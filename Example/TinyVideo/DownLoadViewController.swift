//
//  DownLoadViewController.swift
//  TinyVideo_Example
//
//  Created by hao yin on 2021/3/19.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import WebKit
import TinyVideo
class DownLoadViewController: UIViewController,AVAssetDownloadDelegate {

    @IBOutlet weak var webView:TinyVideoWebView!
    @IBOutlet weak var textfield:UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.isToolbarHidden = false;
        self.webView.handleVideoAsset = { i in
            let play = AVPlayerViewController()
            play.player = AVPlayer(playerItem: AVPlayerItem(asset: i.asset))
            play.player?.play()
            self.present(play, animated: true, completion: nil)
        }
        self.webView.handleIframe = { i in
            self.webView.load(URLRequest(url: i))
        }
        self.webView.handleDownload = { i in
            TinyVideoResourceManager.shared.download(url: i, identidy: "") { (u) in
                guard let url = u else { return }
                TinyVideoGallery.saveVideo(url: url) { (i) in
                    
                }
            }
        }
    }
    @IBAction func run(){
        guard let urltext = self.textfield.text else { return }
        guard let url = URL(string: urltext) else { return }
        self.webView.load(URLRequest(url: url))
        self.view.window?.endEditing(true)
//
    }
    @IBAction func download(_ sender: Any) {
        self.webView.downloadWebVideo()
    }
    @IBAction func hackVideo(){
        self.webView.hackWebVideo()
    }
    @IBAction func openIframeUrl(_ sender: Any) {
        self.webView.hackIframe()
    }
    @IBAction func boBack(_ sender: Any) {
        self.webView.goBack()
    }
}
