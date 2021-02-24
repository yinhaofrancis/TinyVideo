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

class ViewController: UIViewController,UIImagePickerControllerDelegate,UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
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
    
    public func ciUrl(u:URL){
        let filter = DynamicGaussBackgroundFilter()
        let process = TinyCoreImageProcess(filter: filter)
        do {
            let outUrl = try self.filecreate(name: "a", ext: "mp4")
            let input = try TinyAssetVideoProcessInput(asset: AVAsset(url: u))
            let output = try TinyAssetVideoProcessOut(url: outUrl, type: .mp4)
            let size = CGSize(width: 720, height: 1280)
            output.setSourceSize(size: size)
            filter.screenSize = size
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
    @IBAction func pickmtImage(_ sender: UIButton) {
        self.loadlib(mt: true)

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
                self.ciUrl(u: u)
            }
        }
    }
}

//public class koo: TinyFilter {
//    public func filter(image: CIImage,time:CMTime) -> CIImage? {
//        autoreleasepool { () -> CIImage? in
//
//            guard let ctxt = self.cgctx else { return nil }
//
//            guard let cg = cictx.createCGImage(image, from: image.extent) else { return nil }
//
//            ctxt.draw(image: cg, mode: .resizeFill)
//
//            let fs = CTFramesetterCreateWithAttributedString(self.text as CFAttributedString)
//
//            let text = CTFramesetterCreateFrame(fs, CFRangeMake(0, self.text.length), CGPath(rect: self.frame, transform: nil), nil)
//
//            CTFrameDraw(text, ctxt.context)
//
//            guard let img = self.cgctx?.context.makeImage() else { return nil }
//
//            return CIImage(cgImage: img)
//        }
//    }
//    lazy var cgctx:TinyDrawContext? = {
//        guard let rect = self.screenSize else { return nil }
//        let context = TinyDrawContext(width: Int(rect.width), height: Int(rect.height), bytesPerRow: Int(rect.width * 4), buffer: nil)
//        return context
//    }()
//
//    public init(string:NSAttributedString,frame:CGRect) {
//        self.text = string
//        self.frame = frame
//    }
//    public var screenSize: CGSize?
//
//    var cictx:CIContext = CIContext()
//
//    public var text:NSAttributedString
//
//    public var frame:CGRect
//}
