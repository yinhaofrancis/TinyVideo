//
//  File.swift
//  TinyVideo
//
//  Created by hao yin on 2021/3/16.
//

import QuartzCore


public class TinyDrawImage{
    public let width:Int
    public let height:Int
    
    private static var queue:DispatchQueue = DispatchQueue(label: "TinyDrawImage", qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    
    public var context:CGContext?{
        return CGContext(data: nil, width: self.width, height: self.height, bitsPerComponent: 8, bytesPerRow: 4 * self.width, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }
    
    public init(width:Int,height:Int){
        self.width = width
        self.height = height
    }
    
    public func draw(callback:(CGContext)->Void)->CGImage?{
        guard let ctx = self.context else { return nil }
        callback(ctx)
        return ctx.makeImage()
    }
    public func perform(callback: @escaping ()->Void){
        TinyDrawImage.queue.async(execute: callback)
    }
}
