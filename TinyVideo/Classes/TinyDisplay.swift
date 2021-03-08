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
        if let pl = self.player,let item = pl.currentItem{
            if let px = self.getCurrentPixelBuffer(),item.status == .readyToPlay{
                guard let texture = self.render.configuration.createTexture(img: px) else { return }
                self.render.screenSize = self.showSize;
                if let p = self.player , p.currentPresentTransform != .identity{

                    guard let outTexture = self.videoFilter.filterTexture(pixel: texture, w: Float(texture.height), h: Float(texture.width)) else { return }
                    
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
        return self.player?.copyPixelbuffer()
    }
    public func clean(){
        self.render.vertice = nil
    }
    lazy private var videoFilter:TinyMetalFilter = {
        return TinyTransformFilter(configuration: render.configuration)!
    }()
    private var render:TinyTextureRender
    private var timer:CADisplayLink?
    
    public init(configuration:TinyMetalConfiguration = .defaultConfiguration) {
        self.render = TinyTextureRender(configuration: configuration)
        super.init()
        self.contentsScale = UIScreen.main.scale;
    }
    
    required init?(coder: NSCoder) {
        self.render = TinyTextureRender(configuration: .defaultConfiguration)
        super.init(coder: coder)
        self.contentsScale = UIScreen.main.scale;
    }
    public override init() {
        self.render = TinyTextureRender(configuration: .defaultConfiguration)
        super.init()
        self.contentsScale = UIScreen.main.scale;
    }
    
    
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
