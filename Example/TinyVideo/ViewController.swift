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

    
    var i = 0
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

    }
    
    var session:TinyVideoSession?
    
    func process(url:URL){
        let filter = ChromeFilter()
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
    
    @IBAction func export(_ sender: Any) {
        let u = Bundle.main.url(forResource: "IMG_0053", withExtension: "MOV")
        self.process(url: u!)
    }
    
    @IBAction func pickImage(_ sender: Any) {
        let a = UIImagePickerController()
        a.sourceType = .photoLibrary
        a.mediaTypes = [kUTTypeMovie as String]
        a.delegate = self
        a.videoQuality = .typeHigh
        a.allowsEditing = false
        
        a.delegate = self
        i = 0
        self.present(a, animated: true, completion: nil)
    }
//    private func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//        print(info)
////        picker.dismiss(animated: true, completion: nil)
//
//    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        let u = info[.mediaURL]
        process(url: u as! URL)
    }
}
