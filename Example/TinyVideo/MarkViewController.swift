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

class MarkViewController: UIViewController,UIImagePickerControllerDelegate,UINavigationControllerDelegate {

    @IBAction func call(_ sender: UISlider) {
        self.call(i: sender.value)
    }
    @IBOutlet weak var img: UIImageView!
    var asset:AVAsset?
    var ctx:TinyVideoContext = TinyVideoContext(size: CGSize(width: 200, height: 200))
    var track:TinyVideoTrack?
    override func viewDidLoad() {
        super.viewDidLoad()
//        let a = UIImagePickerController()
//        a.sourceType = .photoLibrary
//        a.mediaTypes = [kUTTypeMovie as String]
//        a.delegate = self
//        a.videoQuality = .typeHigh
//        a.allowsEditing = false
//        a.delegate = self
//        self.present(a, animated: true, completion: nil)
//        do {
        let tiny = try! TinyComputer()
        try! tiny.begin()
        let buffera = tiny.createBuffer(size: 10 * MemoryLayout<Float>.size)!
        let bufferb = tiny.createBuffer(size: 10 * MemoryLayout<Float>.size)!
        let bufferr = tiny.createBuffer(size: 10 * MemoryLayout<Float>.size)!
        
        loadbuffer(buffer: buffera)
        loadbuffer(buffer: bufferb)
        
        try! tiny.compute(name: "add_arrays", threadGridSize: MTLSize(width: 10, height: 1, depth: 1),buffers: buffera,bufferb,bufferr)
        
        try! tiny.commit()
        
        showBuffer(buffer: bufferr)
        
    }

    func loadbuffer(buffer:MTLBuffer){
        let a = buffer.contents()
        for i in 0 ..< 10 {
            let f = Float(i)
//            print(f)
            a.storeBytes(of: f, toByteOffset: i * MemoryLayout<Float>.size, as: Float.self)
        }
    }
    
    func showBuffer(buffer:MTLBuffer){
        let r = buffer.contents()
        for i in 0 ..< 10 {
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
        let c = ctx.exportFrame(time: CMTime(seconds: Double(i), preferredTimescale: .max)) { (t, c) in
            guard let cv = self.track?.nextSampleBuffer(current: t) else { return }

            c.drawImage(pixel: cv, frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        }!
        let i = UIImage(cgImage: c)
        self.img.image = i
        
        
    }
}
