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


class mark:NSObject{
    var i:Int
    public init(i:Int){
        self.i = i
    }
    deinit {
        print("ok\(self.i)")
    }
}

class ViewController: UIViewController,UIImagePickerControllerDelegate,UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func make(i:Int) -> mark {
        return autoreleasepool {
            mark(i: i)
        }
    }
    func m(m: @escaping ()->Void) {
        DispatchQueue.global().async {
            m()
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

    }

    var session:TinyVideoSession?

    func process(url:URL){
        let filter = TinyFilterGroup()
        filter.addFilter(filter: DynamicGaussBackgroundFilter())
        filter.addFilter(filter: koo(string: NSAttributedString(string: "dsasds", attributes: [.font:UIFont.systemFont(ofSize: 20),.foregroundColor:UIColor.white]), frame: CGRect(x:20,y:20,width: 100,height: 24)))
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
    @IBAction func pickImage(_ sender: Any) {
        let a = UIImagePickerController()
        a.sourceType = .photoLibrary
        a.mediaTypes = [kUTTypeMovie as String]
        a.delegate = self
        a.videoQuality = .typeHigh
        a.allowsEditing = false
        a.delegate = self
        self.present(a, animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        let u = info[.mediaURL]
        process(url: u as! URL)
    }
}

public class koo: TinyFilter {
    public func filter(image: CIImage, transform: CGAffineTransform,time:CMTime) -> CIImage? {
        autoreleasepool { () -> CIImage? in
            
            guard let ctxt = self.cgctx else { return nil }
            
            guard let cg = cictx.createCGImage(image.transformed(by: transform), from: image.extent) else { return nil }
            
            ctxt.draw(image: cg, mode: .resizeFill)
            
            let fs = CTFramesetterCreateWithAttributedString(self.text as CFAttributedString)
        
            let text = CTFramesetterCreateFrame(fs, CFRangeMake(0, self.text.length), CGPath(rect: self.frame, transform: nil), nil)
            
            CTFrameDraw(text, ctxt.context)
            
            guard let img = self.cgctx?.context.makeImage() else { return nil }
            
            return CIImage(cgImage: img)
        }
    }
    lazy var cgctx:TinyDrawContext? = {
        guard let rect = self.screenSize else { return nil }
        let context = TinyDrawContext(width: Int(rect.width), height: Int(rect.height), bytesPerRow: Int(rect.width * 4), buffer: nil)
        return context
    }()
    
    public init(string:NSAttributedString,frame:CGRect) {
        self.text = string
        self.frame = frame
    }
    public var screenSize: CGSize?
    
    var cictx:CIContext = CIContext()
    
    public var text:NSAttributedString
    
    public var frame:CGRect
}
