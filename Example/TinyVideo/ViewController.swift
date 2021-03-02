//
//  ViewController.swift
//  TinySocket
//
//  Created by yinhaoFrancis on 01/22/2021.
//  Copyright (c) 2021 yinhaoFrancis. All rights reserved.
//

import UIKit
import TinyVideo
import MobileCoreServices
import AVFoundation
import AVKit
import MetalKit

class ViewController: UIViewController,UIImagePickerControllerDelegate,UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBOutlet weak var displayView: TinyVideoView!
    

    var player:TinyVideoPlayer?
    var comp = TinyTransformFilter(configuration: .defaultConfiguration)
    var session:TinyVideoSession?
    var useMt:Bool = false
    func play(url:URL) {
        DispatchQueue.main.async {
            let play = AVPlayerViewController()
            play.player = AVPlayer(url: url)
            play.player?.play()
            self.present(play, animated: true, completion: nil)
        }
    }
    func playmt(url:URL) {
        self.player = TinyVideoPlayer(url: url)
        self.displayView.videoLayer.player = self.player
        
//        self.displayView.videoLayer.videoFilter = self.comp         
        self.player?.play()
        self.displayView.videoLayer.clean()
    }
    func filecreate(name:String,ext:String) throws->URL{
        let outUrl = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(name).appendingPathExtension(ext)
        if FileManager.default.fileExists(atPath: outUrl.path){
            try FileManager.default.removeItem(at: outUrl)
        }
        return outUrl
    }
    @IBAction func pickImage(_ sender: UIButton) {
        self.loadlib(mt: false)
    }
    public func loadMTURL(u:URL){
        let trace = try! TinyAssetVideoTrack(asset: AVAsset(url: u))
        let f = TinyGaussBackgroundFilter(configuration: TinyMetalConfiguration.defaultConfiguration)
        f?.w = 720
        f?.h = 1280
        trace.filter = f
        try! trace.export(w: 720, h: 1280) { (u, s) in
            if let uu = u {
                self.play(url: uu)
            }

        }
    }
    
    @IBAction func pickmtImage(_ sender: UIButton) {
        self.loadlib(mt: true)
    }

    func process(url:URL){
        let filter = DynamicGaussBackgroundFilter()
        filter.saveCache = false
        let process = TinyCoreImageProcess(filter: filter)
        
        do {
            let outUrl = try self.filecreate(name: "a", ext: "mp4")
            let input = try TinyAssetVideoProcessInput(asset: AVAsset(url: url))
            let output = try TinyAssetVideoProcessOut(url: outUrl, type: .mp4)
            output.setSourceSize(size: CGSize(width: UIScreen.main.bounds.size.width * UIScreen.main.scale, height: UIScreen.main.bounds.size.height * UIScreen.main.scale))
            filter.screenSize = UIScreen.main.bounds.size
            self.session = TinyVideoSession(input: input, out: output, process: process)
            self.session?.run { [weak self]i in
                if i == nil{
                    self?.play(url: outUrl)
                    self?.session = nil
                }
            }
        } catch  {
            print(error)
        }
        
        
    }
    func loadlib(mt:Bool){
        let img = UIImagePickerController()
        self.useMt = mt
        img.delegate = self
        img.sourceType = .photoLibrary
        img.mediaTypes = [kUTTypeMovie as String]
        img.videoQuality = .typeIFrame1280x720
        self.present(img, animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        if let u = info[.mediaURL] as? URL{
            if self.useMt{
                self.loadMTURL(u: u)
            }else{
                self.playmt(url: u)
            }
        }
    }
}
