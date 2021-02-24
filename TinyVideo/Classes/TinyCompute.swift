//
//  TinyCompute.swift
//  TinyVideo
//
//  Created by hao yin on 2021/2/24.
//

import Metal
import simd
import MetalPerformanceShaders


public class TinyComputer{
    public var device:MTLDevice{
        self.configuration.device
    }
    public var queue:MTLCommandQueue{
        self.configuration.queue
    }
    
    
    #if DEBUG
    private var debug:Any?
    #endif
    public let configuration:TinyMetalConfiguration
    public init(configuration:TinyMetalConfiguration = TinyMetalConfiguration.defaultConfiguration) throws {
        self.configuration = configuration
        
    }
    #if DEBUG
    
    public func startDebug(){
        if #available(iOS 11.0, *) {
            let sharedCapturer = MTLCaptureManager.shared()
            let scop = sharedCapturer.makeCaptureScope(commandQueue:queue)
            self.debug = scop
            scop.label = "TinyComputer debug"
            scop.begin()
            sharedCapturer.defaultCaptureScope = scop
        } else {
            // Fallback on earlier versions
        }
        
    }
    
    public func endDebug(){
        if #available(iOS 11.0, *) {
            let scop:MTLCaptureScope? = self.debug as? MTLCaptureScope
            scop?.end()
        } else {
            // Fallback on earlier versions
        }
    }
    
    #endif
    
    
    
    public func compute(name:String,pixelSize:MTLSize? = nil,buffers:[MTLBuffer] = [],textures:[MTLTexture] = []) throws{
        try self.startEncoder(name: name,callback: { (encoder) in
            
            
            if(textures.count > 0){
                encoder .setTextures(textures, range: 0 ..< textures.count)
            }
            if(buffers.count > 0){
                encoder.setBuffers(buffers, offsets: (0 ..< buffers.count).map({_ in 0}), range: 0 ..< buffers.count)
            }
            if let gsize = pixelSize{
                let max = Int(sqrt(Double(self.device.maxThreadsPerThreadgroup.width)))
                let x = Int(ceil(Float(gsize.width) / Float(max)))
                let y = Int(ceil(Float(gsize.height) / Float(max)))
                let s = MTLSize(width: x, height: y, depth: 1)
                encoder.dispatchThreadgroups(s, threadsPerThreadgroup: MTLSize(width: max, height: max, depth: 1))
                
            }
            encoder.endEncoding()
        })
        
        #if DEBUG
        self.endDebug()
        #endif
    }
    public typealias EncoderBlock = (MTLComputeCommandEncoder) throws ->Void
    public func startEncoder(name:String,callback:EncoderBlock)throws{
        #if DEBUG
        self.startDebug()
        #endif
        guard let function = self.configuration.shaderLibrary.makeFunction(name: name) else {
            throw NSError(domain: "can't load function \(name)", code: 0, userInfo: nil)
        }
        let state = try self.device.makeComputePipelineState(function: function)
        guard let cmdBuffer = self.configuration.commandbuffer else {
            throw NSError(domain: "you should call begin before startEncorder", code: 0, userInfo: nil)
        }
        guard let encoder = cmdBuffer.makeComputeCommandEncoder() else {
            throw NSError(domain: "you should create command Encoder", code: 0, userInfo: nil)
        }
        encoder.setComputePipelineState(state)
        try callback(encoder)
    }
    public func encoderTexture(encoder:MTLComputeCommandEncoder,textures:[MTLTexture]){
        if textures.count > 0{
            encoder.setTextures(textures, range: 0 ..< textures.count)
        }
    }
    
}
public protocol TinyMetalFilter{
    func filter(pixel:CVPixelBuffer)->CVPixelBuffer?
}
public class TinyGaussBackgroundFilter:TinyMetalFilter{
    public func filter(pixel: CVPixelBuffer) -> CVPixelBuffer? {
        guard let px = self.filterTexture(pixel: pixel, w: self.w, h: self.h) else { return nil }
        return TinyMetalConfiguration.createPixelBuffer(texture: px)
    }
    
    public func filterTexture(pixel:CVPixelBuffer,w:Float,h:Float)->MTLTexture?{
        autoreleasepool { () -> MTLTexture? in
            do {
                let ow = Float(CVPixelBufferGetWidth(pixel))
                let oh = Float(CVPixelBufferGetHeight(pixel))
                
                guard let px1 = self.tiny.configuration.createTexture(img: pixel) else { return nil }
                guard let px2 = self.tiny.configuration.createTexture(width: Int(w), height: Int(h),store: .private) else { return nil }
                guard let px3 = self.tiny.configuration.createTexture(width: Int(w), height: Int(h)) else { return nil }
                try self.tiny.configuration.begin()
                try self.tiny.compute(name: "imageScaleToFill", pixelSize: MTLSize(width: Int(ow * max(h / oh , w / ow)), height: Int(oh * max(h / oh , w / ow)), depth: 1), buffers: [], textures: [px1,px2])
                self.blur.encode(commandBuffer: self.tiny.configuration.commandbuffer!, sourceTexture: px2, destinationTexture: px3)
                try self.tiny.compute(name: "imageScaleToFit", pixelSize: MTLSize(width: Int(ow), height: Int(oh), depth: 1), buffers: [], textures: [px1,px3])
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
            self.blur = MPSImageGaussianBlur(device: configuration.device, sigma: 20)
        } catch  {
            return nil
        }
    }
    public var w:Float = 720
    public var h:Float = 1280
    public var tiny:TinyComputer
    public var blur:MPSImageGaussianBlur
}