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
class DownLoadViewController: UIViewController,AVAssetDownloadDelegate {

    var task:AVAssetDownloadTask?
    @IBOutlet weak var url: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()

    
        
    }
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didResolve resolvedMediaSelection: AVMediaSelection) {

    }
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        print(timeRange)
    }
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
//        self .performSegue(withIdentifier: "play", sender: location)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

    }
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {

    }
    lazy var session:AVAssetDownloadURLSession = {
        AVAssetDownloadURLSession(configuration: .background(withIdentifier: "com.tiny.video"), assetDownloadDelegate: self, delegateQueue: OperationQueue.main)
    }()

    @IBAction func download(_ sender: Any) {
        guard let urlstr = self.url.text else { return }
        guard let url = URL(string: urlstr) else { return }
        let asset = AVURLAsset(url: url)
//        self.task = self.session.aggregateAssetDownloadTask(with: asset, mediaSelections: asset.allMediaSelections, assetTitle: "", assetArtworkData: nil, options: nil)
//        self.task?.resume()
        self.view.backgroundColor = UIColor.gray;
        self.task = self.session.makeAssetDownloadTask(asset: asset, assetTitle: "ddd", assetArtworkData: nil, options: nil)
        self.task?.resume()
        
        
        
   
        
    }
    @IBAction func play(_ sender: Any){
        guard let tas = self.task else { return  }
        let play = AVPlayerViewController()
        play.player = AVPlayer(playerItem: AVPlayerItem(asset: tas.urlAsset))
        play.player?.play()
        self.present(play, animated: true, completion: nil)
    }
}
