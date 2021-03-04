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
    
    @IBOutlet weak var selectGpu:UISwitch!
    @IBOutlet weak var selectTinyPlay:UISwitch!
    
    @IBOutlet weak var displayView: TinyVideoView!
    

    var render = TinyTextureRender(configuration: .defaultConfiguration)
    var player:TinyVideoPlayer?
    var comp = TinyTransformFilter(configuration: .defaultConfiguration)
    var session:TinyVideoSession?
    var noProcess:Bool = false
    func play(useSystem:Bool,url:URL) {
        if useSystem{
            DispatchQueue.main.async {
                let play = AVPlayerViewController()
                play.player = AVPlayer(url: url)
                play.player?.play()
                self.present(play, animated: true, completion: nil)
            }
        }else{
            self.player = TinyVideoPlayer(url: url)
            self.displayView.videoLayer.player = self.player
            self.player?.play()
            self.displayView.videoLayer.clean()
        }
        
    }
    func filecreate(name:String,ext:String) throws->URL{
        let outUrl = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(name).appendingPathExtension(ext)
        if FileManager.default.fileExists(atPath: outUrl.path){
            try FileManager.default.removeItem(at: outUrl)
        }
        return outUrl
    }
    @IBAction func pickImage(_ sender: UIButton) {
        self.loadlib(noProcess: true)
    }
    
    
    @IBAction func pickmtImage(_ sender: UIButton) {
        self.loadlib(noProcess: false)
    }
    
    
    func process(useGpu:Bool,u:URL){
        if(useGpu){
            self.processGPU(u: u)
        }else{
            self.processCPU(url: u)
        }
    }
    
    func processGPU(u:URL){
        let trace = try! TinyAssetVideoTrack(asset: AVAsset(url: u))
        let f = TinyGaussBackgroundFilter(configuration: TinyMetalConfiguration.defaultConfiguration)
        f?.w = 720
        f?.h = 1280
        trace.filter = f
        try! trace.export(w: 720, h: 1280) { (u, s) in
            if let uu = u {
                DispatchQueue.main.async {
                    self.play(useSystem: !self.selectTinyPlay.isOn, url: uu)
                }
            }

        }
    }
    func processCPU(url:URL){
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
                    if let ws = self{
                        DispatchQueue.main.async {
                            ws.play(useSystem: !ws.selectTinyPlay.isOn, url: outUrl)
                            ws.session = nil
                        }
                    }
                    
                }
            }
        } catch  {
            print(error)
        }
    }
    func loadlib(noProcess:Bool){
        let img = UIImagePickerController()
        self.noProcess = noProcess
        img.delegate = self
        img.sourceType = .photoLibrary
        img.mediaTypes = [kUTTypeMovie as String]
        img.videoQuality = .typeIFrame1280x720
        self.present(img, animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        if let u = info[.mediaURL] as? URL{
            if self.noProcess{
                self.play(useSystem: !self.selectTinyPlay.isOn, url: u)
            }else{
                self.process(useGpu: self.selectGpu.isOn, u: u)
            }
            
        }
    }
    @IBAction func test(){
        let a =  #imageLiteral(resourceName: "mm").cgImage!

        let text = try! MTKTextureLoader(device: self.render.configuration.device).newTexture(cgImage: a, options: nil)
        self.displayView.videoLayer.drawableSize = self.displayView.videoLayer.renderSize
        guard let draw = self.displayView.videoLayer.nextDrawable() else { return  }
        self.render.screenSize = self.displayView.videoLayer.showSize
        self.render.ratio = Float(1280) / Float(720)
        guard let rt = comp?.filterTexture(pixel: text, w: 720, h: 1280) else { return }
        try! self.render.configuration.begin()
        try! self.render.render(texture: rt,drawable: draw)
        try! self.render.configuration.commit()
    }
    
}
