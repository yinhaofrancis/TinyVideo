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
    let tiny = try! TinyComputer()
    var asset:AVAsset?
    var ctx:TinyVideoContext = TinyVideoContext(size: CGSize(width: 200, height: 200))
    var track:TinyVideoTrack?
    var render:TinyRender?
    
    var blur:MPSImageGaussianBlur!
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
        self.asset = AVAsset(url: u)
        self.track = try! TinyAssetVideoTrack(asset: self.asset!)
        self.track?.ready()
        self.call(i: 0)
    }
    func call(i:Float){
        var img:CIImage?
        let grid:Float = 10;
        
        ctx.exportFrame(time: CMTime(seconds: Double(i), preferredTimescale: .max)) { (t, c) in
            guard let cv = self.track?.nextSampleBuffer(current: t) else { return }
            let temp:[Float] = [grid];
            let d = self.tiny.createBuffer(data: temp)
            let px1 = self.tiny.createTexture(img: cv)
//            try! self.render?.configuration.begin()
//
//            let r = MTLRenderPassDescriptor()
//            r.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
//
//            try! self.render?.render(texture: px1!, renderPass: self.img.currentRenderPassDescriptor!, drawable: self.img.currentDrawable!)
//            try! self.render?.configuration.commit()
            
            let w = Int(Double(CVPixelBufferGetWidth(cv)) * 0.5)
            let h = Int(Double(CVPixelBufferGetHeight(cv)) * 0.5)
            let px2 = self.tiny.createTexture(width: w, height: h)
            let px3 = self.tiny.createTexture(width: w, height: h)
            try! self.tiny.configuration.begin()
            try! self.tiny.compute(name: "imageScaleToFit", pixelSize: MTLSize(width: w, height: h, depth: 1), buffers: [], textures: [px1!,px2!])
//            self.blur.encode(commandBuffer: self.tiny.commandbuffer!, sourceTexture: self.img.currentDrawable!.texture, destinationTexture: px3!)
            try! self.tiny.configuration.commit()
            img = CIImage(mtlTexture: px2!, options: nil)
        }
        self.imgv.image = UIImage(ciImage: img!, scale: UIScreen.main.scale, orientation: .up)
        
    }
}
