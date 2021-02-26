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
        self.displayView.videoLayer.device = self.render.configuration.device
        self.ren = TinyRender(configuration: .defaultConfiguration, w: Float(self.displayView.frame.size.width), h: Float(self.displayView.frame.size.height))
    }
    
    @IBOutlet weak var displayView: TinyVideoView!
    
    
    var render:TinyTextureRender = TinyTextureRender(configuration: .defaultConfiguration)
    
    var ren: TinyRender?
    
    var comp = TinyGaussBackgroundFilter(configuration: .defaultConfiguration)
    
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
    func filecreate(name:String,ext:String) throws->URL{
        let outUrl = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(name).appendingPathExtension(ext)
        if FileManager.default.fileExists(atPath: outUrl.path){
            try FileManager.default.removeItem(at: outUrl)
        }
        return outUrl
    }
    @IBAction func pickImage(_ sender: UIButton) {
        self.go(sigma: 50)
    }
    func go(sigma:Float){
//        let a =  #imageLiteral(resourceName: "mm").cgImage!
//
//        let text = try! MTKTextureLoader(device: TinyMetalConfiguration.defaultConfiguration.device).newTexture(cgImage: a, options: nil)
//        self.displayView.videoLayer.drawableSize = self.displayView.videoLayer.renderSize
        guard let draw = self.displayView.videoLayer.nextDrawable() else { return  }
        
//        self.render.screenSize = self.displayView.videoLayer.showSize
//        self.render.ratio = Float(1280) / Float(720)
//        guard let rt = comp?.filterTexture(pixel: text, w: 720, h: 1280) else { return }
        
        let v = TinyView(frame: Rect(x: 10, y: 10, w: 50, h: 50), configuration: .defaultConfiguration, vertex: "vertexShader", fragment: "testShader")
        
        
        try! TinyMetalConfiguration.defaultConfiguration.begin()
        try! self.ren?.render(layer: v, drawable: draw)
//        try! self.render.render(texture: rt,drawable: draw)
        try! TinyMetalConfiguration.defaultConfiguration.commit()
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
    @IBAction func slider(sender:UISlider){
        self.go(sigma: sender.value)
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
            }
        }
    }
}
