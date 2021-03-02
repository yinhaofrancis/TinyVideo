//
//  File.swift
//  TinyVideo
//
//  Created by hao yin on 2021/2/24.
//

import Metal
import AVFoundation

public class TinyVideoLayer:CAMetalLayer{
    
    public var renderSize:CGSize{
        return CGSize(width: self.frame.size.width * UIScreen.main.scale , height: self.frame.size.height * UIScreen.main.scale)
    }
    public var showSize:CGSize{
        return CGSize(width: self.frame.size.width * UIScreen.main.scale , height: self.frame.size.height * UIScreen.main.scale)
    }
    var lastTimestamp:CFTimeInterval = 0;
    var lastPixelBuffer:CVPixelBuffer?
    public var player:TinyVideoPlayer?{
        didSet{
            if self.player != nil{
                self.timer = CADisplayLink(target: self, selector: #selector(renderVideo))
                self.timer?.add(to: RunLoop.main, forMode: .common)
                self.device = self.render.configuration.device
            }else{
                self.timer?.invalidate()
                self.timer = nil
            }
        }
    }
    @objc func renderVideo(){
        if let pl = self.player{
            if let px = self.getCurrentPixelBuffer(),pl.status == .readyToPlay{
                guard let texture = self.render.configuration.createTexture(img: px) else { return }
                self.render.screenSize = self.showSize;
                if let filter = self.videoFilter{

                    guard let outTexture = filter.filterTexture(pixel: texture, w: Float(self.render.screenSize.width), h: Float(self.render.screenSize.height)) else { return }
                    
                    guard let draw = self.nextDrawable() else { return  }
                    do {
                        try self.render.configuration.begin()
                        self.render.ratio = Float(outTexture.height) / Float(outTexture.width)
                        try self.render.render(texture: outTexture, drawable: draw)
                        try self.render.configuration.commit()
                    } catch {
                        return
                    }
                }else{
                    guard let draw = self.nextDrawable() else { return  }
                    do {
                        try self.render.configuration.begin()
                        self.render.ratio = Float(texture.height) / Float(texture.width)
                        try self.render.render(texture: texture, drawable: draw)
                        try self.render.configuration.commit()

                    } catch {
                        return
                    }
                }
                
                
                
            }
        }else{
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    func getCurrentPixelBuffer()->CVPixelBuffer?{
        if let px = self.player?.copyPixelbuffer(){
            self.lastPixelBuffer = px
            return px
        }else{
            return self.lastPixelBuffer
        }
    }
    public func clean(){
        self.render.vertice = nil
//        self.render.screenSize = 
    }
    public var videoFilter:TinyMetalFilter?
    private var render = TinyTextureRender(configuration: .defaultConfiguration)
    private var timer:CADisplayLink?
    
    
    
}

public class TinyVideoView:UIView{
    public override class var layerClass: AnyClass{
        return TinyVideoLayer.self
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.videoLayer.pixelFormat = .bgra8Unorm_srgb
        self.videoLayer.contentsScale = UIScreen.main.scale
        self.videoLayer.rasterizationScale = UIScreen.main.scale
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.videoLayer.pixelFormat = .bgra8Unorm_srgb
        self.videoLayer.contentsScale = UIScreen.main.scale
        self.videoLayer.rasterizationScale = UIScreen.main.scale
    }
    public var videoLayer:TinyVideoLayer{
        return self.layer as! TinyVideoLayer
    }
}
