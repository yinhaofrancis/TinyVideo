//
//  TinyMetalFilter.swift
//  TinyVideo
//
//  Created by hao yin on 2021/3/24.
//

import Foundation
import Metal
import MetalPerformanceShaders

public protocol TinyMetalFilter{
    func filter(pixel:CVPixelBuffer)->CVPixelBuffer?
    func filterTexture(pixel:MTLTexture,w:Float,h:Float)->MTLTexture?
}
public class TinyGaussBackgroundFilter:TinyMetalFilter{
    public func filter(pixel: CVPixelBuffer) -> CVPixelBuffer? {
        guard let px1 = self.tiny.configuration.createTexture(img: pixel) else { return nil }
        guard let px = self.filterTexture(pixel: px1, w: self.w, h: self.h) else { return nil }
        return TinyMetalConfiguration.createPixelBuffer(texture: px)
    }
    
    public func filterTexture(pixel:MTLTexture,w:Float,h:Float)->MTLTexture?{
        autoreleasepool { () -> MTLTexture? in
            do {
                let ow = Float(pixel.width)
                let oh = Float(pixel.height)
                
                let px1 = pixel
                guard let px2 = self.tiny.configuration.createTexture(width: Int(w), height: Int(h),store: .private) else { return nil }
                guard let px3 = self.tiny.configuration.createTexture(width: Int(w), height: Int(h)) else { return nil }
                try self.tiny.configuration.begin()
                let psize =  MTLSize(width: Int(ow * max(h / oh , w / ow)), height: Int(oh * max(h / oh , w / ow)), depth: 1)
                try self.tiny.compute(name: "imageScaleToFill", pixelSize:psize, buffers: [], textures: [px1,px2])
                
                self.blur.encode(commandBuffer: self.tiny.configuration.commandbuffer!, sourceTexture: px2, destinationTexture: px3)
                try self.tiny.compute(name: "imageScaleToFit", pixelSize: psize, buffers: [], textures: [px1,px3])
                try self.tiny.configuration.commit()
                return px3
                
            } catch  {
                return nil
            }
        }
        
    }
    public init?(configuration:TinyMetalConfiguration) {
        do {
            self.tiny = try TinyComputer(configuration: configuration)
            self.blur = MPSImageGaussianBlur(device: configuration.device, sigma: 30)
        } catch  {
            return nil
        }
    }
    public var w:Float = 720
    public var h:Float = 1280
    public var tiny:TinyComputer
    public var blur:MPSImageGaussianBlur
}
public class TinyTransformFilter:TinyMetalFilter{
    
    private var transform:simd_float3x3 = simd_float3x3([
                                            simd_float3(1, 0, 0),
                                            simd_float3(0, 1, 0),
                                            simd_float3(0, 0, 1)
    ]){
        didSet{
            self.buffer = self.tiny.configuration.createBuffer(data: self.transform)
        }
    }
    public var buffer:MTLBuffer?
    public func filter(pixel: CVPixelBuffer) -> CVPixelBuffer? {
        return nil
    }
    
    public func filterTexture(pixel: MTLTexture, w: Float, h: Float) -> MTLTexture? {
        autoreleasepool { () -> MTLTexture? in
            do {
                let px1 = pixel
                self.transform = simd_float3x3([
                                                simd_float3(0, -1,0),
                                                simd_float3(1, 0, 0),
                                                simd_float3(0, w, 1)])
                guard let px3 = self.tiny.configuration.createTexture(width: Int(w), height: Int(h)) else { return nil }
                try self.tiny.configuration.begin()
                if(self.buffer == nil){
                    self.buffer = self.tiny.configuration.createBuffer(data: self.transform)
                }
                if let buffer = self.buffer{
                    try self.tiny.compute(name: "imageTransform", pixelSize: MTLSize(width: Int(w), height: Int(h), depth: 1), buffers: [buffer], textures: [px1,px3])
                }
                try self.tiny.configuration.commit()
                return px3
                
            } catch  {
                return nil
            }
        }
    }
    
    public init?(configuration:TinyMetalConfiguration) {
        do {
            self.tiny = try TinyComputer(configuration: configuration)
        } catch  {
            return nil
        }
    }
    public var tiny:TinyComputer
}
