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

    var url:URL?
    override func viewDidLoad() {
        super.viewDidLoad()
        if let u = self.url{
            self.play(useTiny: false, url: u)
        }
    }
    
    @IBOutlet weak var displayView: TinyVideoView!
    

    var render = TinyTextureRender(configuration: .defaultConfiguration)
    var player:TinyVideoPlayer?
    lazy var comp:TinyTransformFilter = {
        return TinyTransformFilter(configuration: self.render.configuration)!
    }()
    var session:TinyVideoSession?
    var noProcess:Bool = false
    public func play(useTiny:Bool,url:URL) {
        if useTiny{
            if((self.player) != nil){
                self.player?.pause()
            }
            self.player = TinyVideoPlayer(url: url)
            self.displayView.videoLayer.player = self.player
            self.player?.play()
            self.displayView.videoLayer.clean()
        }else{
            DispatchQueue.main.async {
                let play = AVPlayerViewController()
                play.player = AVPlayer(url: url)
                play.player?.play()
                self.present(play, animated: true, completion: nil)
            }
        }
        
    }
    func filecreate(name:String,ext:String) throws->URL{
        let outUrl = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(name).appendingPathExtension(ext)
        if FileManager.default.fileExists(atPath: outUrl.path){
            try FileManager.default.removeItem(at: outUrl)
        }
        return outUrl
    }
    @IBAction func pickImage() {
        self.loadlib(noProcess: false)
    }
    @IBAction func pickpImage() {
        self.loadlib(noProcess: true)
    }

    func go(sigma:Float){
        let a =  #imageLiteral(resourceName: "mm").cgImage!

        let text = try! MTKTextureLoader(device: TinyMetalConfiguration.defaultConfiguration.device).newTexture(cgImage: a, options: nil)
        self.displayView.videoLayer.drawableSize = self.displayView.videoLayer.showSize
        guard let draw = self.displayView.videoLayer.nextDrawable() else { return  }
        
        self.render.screenSize = self.displayView.videoLayer.showSize
        self.render.ratio = Float(1280) / Float(720)
        
        guard let rt = comp.filterTexture(pixel: [text], w: 720, h: 1280) else { return }
        
        
        
        try! TinyMetalConfiguration.defaultConfiguration.begin()
        try! self.render.render(texture: rt,drawable: draw)
        try! TinyMetalConfiguration.defaultConfiguration.commit()
    }
    
    func processGPU(u:URL){
        let trace = try! TinyAssetVideoTrack(asset: AVAsset(url: u))
        let f = TinyGaussBackgroundFilter(configuration: TinyMetalConfiguration.defaultConfiguration,sigma: self.model.sigma)
        f?.w = 720
        f?.h = 1080
        trace.filter = f
        try! trace.export(w:720,h: 1080) { (u, s) in
            if let uu = u {
                DispatchQueue.main.async {
                    self.saveVideo(url: uu)
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
            output.setSourceSize(size: CGSize(width: 720, height: 1080))
            filter.screenSize = CGSize(width: 720, height: 1080)
            self.session = TinyVideoSession(input: input, out: output, process: process)
            self.session?.run { [weak self]i in
                if i == nil{
                    if let ws = self{
                        DispatchQueue.main.async {
                            ws.session = nil
                            ws.saveVideo(url: outUrl)
                        }
                    }
                    
                }
            }
        } catch  {
            print(error)
        }
    }
    func saveVideo(url:URL){
        let a = UIAlertController(title: "是否保存", message: "是否保存到相册", preferredStyle: .actionSheet)
        a.addAction(UIAlertAction(title: "保存", style: .default, handler: { (a) in
            TinyVideoManager.saveVideo(url: url) { (id) in
                
            }
        }))
        
        a.addAction(UIAlertAction(title: "播放", style: .default, handler: { (a) in
            self.play(useTiny: self.model.selectTinyPlay, url: url)
        }))
        self.present(a, animated: true, completion: nil)
        
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
                self.play(useTiny: self.model.selectTinyPlay, url: u)
            }else{
                if self.model.selectGpu{
                    self.processGPU(u: u)
                }else{
                    self.processCPU(url: u)
                }
               
            }
            
        }
    }
    func render(image:CGImage){

        self.displayView.videoLayer.drawableSize = self.displayView.videoLayer.showSize
        guard let draw = self.displayView.videoLayer.nextDrawable() else { return  }
        self.render.screenSize = self.displayView.videoLayer.showSize
        self.render.ratio = Float(480) / Float(320)
        try! self.render.configuration.begin()
       
        try! self.render.render(image:image, drawable: draw)
        try! self.render.configuration.commit()
    }

    @IBAction func play(segue:UIStoryboardSegue){
        let v = segue.source as! SelectViewController
        self.model = v.model
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        let img = TinyDrawImage(width: 320 * 3, height: 480 * 3).draw { (ctx) in
            ctx.setFillColor(UIColor.red.cgColor)
            ctx.fill(CGRect(x: 10, y: 10, width: 200 * 3, height: 200 * 3))
            let m = NSMutableAttributedString(string: "f0123456789af十大", attributes: [.foregroundColor:UIColor.white,.font:UIFont.systemFont(ofSize: 20 * 3)])
            let img = #imageLiteral(resourceName: "mm").cgImage
            let imgr = TinyTextImage(image: img!, font: CTFontCreateWithName("system" as CFString, 128, nil))
            imgr.contentMode = .scaleToAcceptFill
            let a = NSAttributedString.runDelegate(run: imgr)
            let n = NSMutableAttributedString(string: "f9876543210af", attributes: [.foregroundColor:UIColor.yellow,.font:UIFont.systemFont(ofSize: 20 * 3)])
            m.append(a)
            m.append(n)
            let frame = TinyTextFrame(string:m, range: CFRange(location: 0, length: m.length), path: CGPath(rect: CGRect(x: 10, y: 10, width: 200 * 3, height: 200 * 3), transform: nil))
           
            frame.draw(ctx: ctx)
        }
        self.render(image: img!)

    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let v = segue.destination as! SelectViewController
        v.model = self.model
    }
    
    
    var model:ConfigModel = ConfigModel(selectGpu: true, selectTinyPlay: true,sigma: 30, url: nil)
}

struct ConfigModel {
    var selectGpu:Bool
    var selectTinyPlay:Bool
    var sigma:Float
    var url:URL?
}

class SelectViewController: UIViewController{

    @IBOutlet weak var selectGpu:UISwitch!
    @IBOutlet weak var selectTinyPlay:UISwitch!
    @IBOutlet weak var displayView: TinyVideoView!
    var render = TinyTextureRender(configuration: .defaultConfiguration)
    var model:ConfigModel = ConfigModel(selectGpu: true, selectTinyPlay: true,sigma: 30, url: nil)
    override func viewDidLoad() {
        super.viewDidLoad()
        self.selectGpu.isOn = self.model.selectGpu
        self.selectTinyPlay.isOn = self.model.selectTinyPlay
    }
    @IBAction func selectGpuAction(_ sender: UISwitch) {
        self.model.selectGpu = sender.isOn
    }
    @IBAction func selectTinyPlayAction(_ sender: UISwitch) {
        self.model.selectTinyPlay = sender.isOn
    }
    @IBAction func changegama(_ sender: UISlider) {
        self.go(sigma: sender.value)
        self.model.sigma = sender.value
    }
    
    func go(sigma:Float){
        let a =  #imageLiteral(resourceName: "mm").cgImage!

        let text = try! MTKTextureLoader(device: TinyMetalConfiguration.defaultConfiguration.device).newTexture(cgImage: a, options: nil)
        self.displayView.videoLayer.drawableSize = self.displayView.videoLayer.showSize
        guard let draw = self.displayView.videoLayer.nextDrawable() else { return  }
        
        self.render.screenSize = self.displayView.videoLayer.showSize
        self.render.ratio = Float(1280) / Float(720)
        let comp = TinyGaussBackgroundFilter(configuration: self.render.configuration,sigma:sigma)
        
        guard let rt = comp?.filterTexture(pixel: [text], w: 720, h: 1280) else { return }
        
        
        
        try! self.render.configuration.begin()
//        try! self.ren?.render(layer: v, drawable: draw)
        try! self.render.render(texture: rt,drawable: draw)
        try! self.render.configuration.commit()
    }
}
