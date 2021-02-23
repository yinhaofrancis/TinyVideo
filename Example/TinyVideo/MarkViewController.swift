//
//  MarkViewController.swift
//  TinyVideo_Example
//
//  Created by hao yin on 2021/2/18.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation
import TinyVideo
import MetalKit
import MetalPerformanceShaders

class MarkViewController: UIViewController,UIImagePickerControllerDelegate,UINavigationControllerDelegate {

    @IBAction func call(_ sender: UISlider) {
        self.call(i: sender.value)
    }
    @IBOutlet weak var img: MTKView!
    @IBOutlet weak var imgv: UIImageView!
    
    var asset:AVAsset?
    
    var render:TinyRender?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let a = UIImagePickerController()
        a.sourceType = .photoLibrary
        a.mediaTypes = [kUTTypeMovie as String]
        a.delegate = self
        a.videoQuality = .typeHigh
        a.allowsEditing = false
        a.delegate = self
        self.present(a, animated: true, completion: nil)
        self.loadvideoUrl(u: Bundle.main.url(forResource: "a", withExtension: "MOV")!)
    }

    func loadbuffer(buffer:MTLBuffer){
        let a = buffer.contents()
        for i in 0 ..< 3 {
            let f = Float(i)
            print(f)
            a.storeBytes(of: f, toByteOffset: i * MemoryLayout<Float>.size, as: Float.self)
        }
    }
    
    func showBuffer(buffer:MTLBuffer){
        let r = buffer.contents()
        for i in 0 ..< 3 {
            let f = r.load(fromByteOffset: i * MemoryLayout<Float>.size, as: Float.self)
            print(f)
        }
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let u = info[.mediaURL] as? URL else { return }
        self.loadvideoUrl(u: u)
    }
    func loadvideoUrl(u:URL){
//        self.asset = AVAsset(url: u)
//        self.track = try! TinyAssetVideoTrack(asset: self.asset!)
//        self.track?.ready()
//        self.call(i: 0)
    }
    func call(i:Float){
//        var img:CIImage?
//        let grid:Float = 10;
//        
//        ctx.exportFrame(time: CMTime(seconds: Double(i), preferredTimescale: .max)) { (t, c) in
//            guard let cv = self.track?.nextSampleBuffer(current: t) else { return }
//            
//            let px1 = self.tiny.createTexture(img: cv)
//            let ow = Float(CVPixelBufferGetWidth(cv));
//            let oh = Float(CVPixelBufferGetHeight(cv));
//            let w:Float = 720
//            let h:Float = 1280.0
//            let px2 = self.tiny.createTexture(width: Int(w), height: Int(h))
//            let px3 = self.tiny.createTexture(width: Int(w), height: Int(h))
//            try! self.tiny.configuration.begin()
//            try! self.tiny.compute(name: "imageScaleToFill", pixelSize: MTLSize(width: Int(ow * max(h / oh , w / ow)), height: Int(oh * max(h / oh , w / ow)), depth: 1), buffers: [], textures: [px1!,px2!])
//            self.blur.encode(commandBuffer: self.tiny.configuration.commandbuffer!, sourceTexture: px2!, destinationTexture: px3!)
//            try! self.tiny.compute(name: "imageScaleToFit", pixelSize: MTLSize(width: Int(ow), height: Int(oh), depth: 1), buffers: [], textures: [px1!,px3!])
//            try! self.tiny.configuration.commit()
//            img = CIImage(mtlTexture: px3!, options: nil)
//        }
//        if let i = img{
//            self.imgv.image = UIImage(ciImage: i)
//        }
    }
}
