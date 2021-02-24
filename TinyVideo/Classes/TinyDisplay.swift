//
//  File.swift
//  TinyVideo
//
//  Created by hao yin on 2021/2/24.
//

import Metal


public class TinyVideoLayer:CAMetalLayer{
    public var ssaa:CGFloat = 1
    public var renderSize:CGSize{
        return CGSize(width: self.frame.size.width * UIScreen.main.scale * ssaa , height: self.frame.size.height * UIScreen.main.scale * ssaa)
    }
    public var showSize:CGSize{
        return CGSize(width: self.frame.size.width * UIScreen.main.scale * ssaa , height: self.frame.size.height * UIScreen.main.scale * ssaa)
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
