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

class ViewController: UIViewController {

    @IBOutlet weak var ySlider: UISlider!
    @IBOutlet weak var xSlider: UISlider!
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    var session:TinyVideoSession?

    @IBOutlet weak var showFBL: UILabel!
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
        let filter = DynamicGaussBackgroundFilter()
        let process = TinyCoreImageProcess(filter: filter)

//        process.outputSize = CGSize(width: 720, height: 1280)
        do {
            let outUrl = try self.filecreate(name: "a", ext: "mp4")

            let input = try TinyAssetVideoProcessInput(asset: self.assets)
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
    
    var assets:AVAsset{
        return AVAsset(url: Bundle.main.url(forResource: "a", withExtension: "MOV")!)
    }
    
    @IBAction func pickmtImage(_ sender: UIButton) {
        
        let trace = try! TinyAssetVideoTrack(asset: self.assets)
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
    @IBAction func fbl(_ sender: Any) {
        self.showFBL.text = "\(UInt(self.xSlider.value))x\(UInt(self.ySlider.value))"
    }
    @IBAction func orgin(_ sender: Any) {
        self.play(url: Bundle.main.url(forResource: "a", withExtension: "MOV")!)
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
