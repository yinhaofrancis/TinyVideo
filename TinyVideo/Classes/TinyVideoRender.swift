//
//  TinyVideoRender.swift
//  TinyVideo
//
//  Created by hao yin on 2021/2/20.
//

import Metal
import simd
public class TinyMetalConfiguration{
    public var device:MTLDevice
    public var queue:MTLCommandQueue
    
    public var commandbuffer:MTLCommandBuffer?
    
    
    public init() throws{
        let device:MTLDevice? = MTLCreateSystemDefaultDevice()
        guard let dev = device else { throw NSError(domain: "can't create metal context", code: 0, userInfo: nil) }
        self.device = dev
        guard let queue = dev.makeCommandQueue() else { throw NSError(domain: "can't create metal command queue", code: 0, userInfo: nil)}
        self.queue = queue
        try self.loadDefaultLibrary()
    }
    private func loadDefaultLibrary() throws{
        guard let url =  Bundle(for: TinyComputer.self).url(forResource: "default", withExtension: "metallib")?.path else { throw NSError(domain: "can't load default metal lib", code: 0, userInfo: nil) }
        self.shaderLibrary = try self.device.makeLibrary(filepath:url)
    }
    public var shaderLibrary:MTLLibrary!
    
    public func begin() throws {
        guard let commandbuffer = self.queue.makeCommandBuffer() else { throw NSError(domain: " can't create command buffer", code: 0, userInfo: nil)}
        self.commandbuffer = commandbuffer
    }
    
    public func commit() throws {
        self.commandbuffer?.commit()
        self.commandbuffer?.waitUntilCompleted()
        self.commandbuffer = nil
        
    }
    
    
    public static var defaultConfiguration:TinyMetalConfiguration = {
        return try! TinyMetalConfiguration()
    }()
}
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
                if(pixelSize?.width != nil){

                    encoder.setBuffers(buffers, offsets: (0 ..< buffers.count).map({_ in 0}), range: 1 ..< buffers.count + 1)
                }else{
                    encoder.setBuffers(buffers, offsets: (0 ..< buffers.count).map({_ in 0}), range: 0 ..< buffers.count)
                }
                
            }
            if let gsize = pixelSize{
                let max = Int(sqrt(Double(self.device.maxThreadsPerThreadgroup.width)))
                let x = Int(ceil(Float(gsize.width) / Float(max)))
                let y = Int(ceil(Float(gsize.height) / Float(max)))
                let s = MTLSize(width: x, height: y, depth: 1)
                var grid = simd_uint2(x: UInt32(x), y: UInt32(y))
                encoder.setBytes(&grid, length: MemoryLayout<simd_int2>.size, index: 0)
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
    private var textureCache:CVMetalTextureCache?
    
    public func createTexture(img:CVPixelBuffer,usage:MTLTextureUsage = [.shaderRead,.shaderWrite])->MTLTexture?{
        let d = MTLTextureDescriptor()
        d.pixelFormat = .bgra8Unorm_srgb
        d.width = CVPixelBufferGetWidth(img)
        d.storageMode = .shared
        d.usage = .shaderRead
        d.height = CVPixelBufferGetHeight(img)
        var mt:CVMetalTexture?
        if(textureCache == nil){
            var c:CVMetalTextureCache?
            CVMetalTextureCacheCreate(nil, nil, self.device, nil, &c)
            self.textureCache = c
        }
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, self.textureCache!, img, nil, d.pixelFormat, d.width, d.height, 0, &mt)
            
        if(status == kCVReturnSuccess) {
            return CVMetalTextureGetTexture(mt!)
        }
        return nil
    }
    
    public func createTexture(width:Int,height:Int,usage:MTLTextureUsage =  [.shaderRead,.shaderWrite])->MTLTexture?{
        let d = MTLTextureDescriptor()
        d.pixelFormat = .bgra8Unorm_srgb
        d.width = width
        d.storageMode = .shared
        d.usage = usage
        d.height = height
        return self.device.makeTexture(descriptor: d)
    }
    
    public func createCVPixelBuffer(img:CGImage)->CVPixelBuffer?{
        let option = [
            kCVPixelBufferCGImageCompatibilityKey:true,
            kCVPixelBufferCGBitmapContextCompatibilityKey:true
        ]
        if let data = img.dataProvider?.data{
            
            let dp = UnsafeMutablePointer<UInt8>.allocate(capacity: CFDataGetLength(data))
            CFDataGetBytes(data, CFRange(location: 0, length: CFDataGetLength(data)), dp)
            var buffer:CVPixelBuffer?
            CVPixelBufferCreateWithBytes(nil, img.width, img.height, kCVPixelFormatType_32ARGB, dp, img.bytesPerRow, nil, nil, option as CFDictionary, &buffer)
        }
        
        return nil
    }
    public func createBuffer<T>(data:[T])->MTLBuffer?{
        let buffer = self.device.makeBuffer(length: MemoryLayout<T>.size * data.count, options: .storageModeShared)
        let ptr = buffer?.contents()
        for i in 0 ..< data.count {
            ptr?.storeBytes(of: data[i], toByteOffset: i * MemoryLayout<T>.size, as: T.self)
        }
        return buffer
    }
    
    public func createBuffer<T>(data:T)->MTLBuffer?{
        let buffer = self.device.makeBuffer(length: MemoryLayout<T>.size, options: .storageModeShared)
        buffer?.contents().storeBytes(of: data, as: T.self)
        return buffer
    }
    public func createBuffer(size:Int)->MTLBuffer?{
        return self.device.makeBuffer(length: size, options: .storageModeShared)
    }
}



public class TinyRender {
    public struct ScreenSize{
        public var w:Float
        public var h:Float
    }
    public struct vertex{
        public var location:simd_float4
        public var texture:simd_float2
    }
    public let configuration:TinyMetalConfiguration
    private let pipelineDescriptor:MTLRenderPipelineDescriptor
    public init(configuration:TinyMetalConfiguration = TinyMetalConfiguration.defaultConfiguration)  {
        self.configuration = configuration
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = configuration.shaderLibrary.makeFunction(name: "vertexShader")
        pipelineDesc.fragmentFunction = configuration.shaderLibrary.makeFunction(name: "fragmentShader")
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        self.pipelineDescriptor = pipelineDesc
    }
    public var screenSize:ScreenSize = ScreenSize(w: 320 * Float(UIScreen.main.scale), h: 480 * Float(UIScreen.main.scale))
    
    public var ortho:float4x4{
        return float4x4(columns: (
            simd_float4(1 / self.screenSize.w, 0, 0, 0),
            simd_float4(0, 1 / self.screenSize.h, 0, 0),
            simd_float4(0, 0, -1, 0),
            simd_float4(0, 0, 0, 1)
        ))
    }
    public lazy var orthoBuffer:MTLBuffer? = {
        let b = self.configuration.device.makeBuffer(length: MemoryLayout<float4x4>.size, options: .storageModeShared)
        b?.contents().storeBytes(of: self.ortho, toByteOffset: 0, as: float4x4.self)
        return b
    }()
    public var rectangle:[vertex]{
        [
        vertex(location: simd_float4(screenSize.w / -2, screenSize.h / 2, 0, 1), texture: simd_float2(0, 0)),
        vertex(location: simd_float4(screenSize.w / 2, screenSize.h / 2, 0, 1), texture: simd_float2(0, 1)),
        vertex(location: simd_float4(screenSize.w / 2, screenSize.h / -2, 0, 1), texture: simd_float2(1, 1)),
        vertex(location: simd_float4(screenSize.w / -2, screenSize.h / -2, 0, 1), texture: simd_float2(1, 0))
        ]
    }
    public lazy var vertice:MTLBuffer? = {
        return self.configuration.device.makeBuffer(bytes: rectangle, length: MemoryLayout<vertex>.size * rectangle.count, options: .storageModeShared)
    }()
    
    
    public lazy var indexVertice:MTLBuffer? = {
        return self.configuration.device.makeBuffer(bytes: rectangleIndex, length: rectangleIndex.count * MemoryLayout<UInt32>.size, options: .storageModeShared)
    }()
    public var rectangleIndex:[UInt32]{
        [
            0,1,2,0,2,3
        ]
    }
    public func render(texture:MTLTexture,renderPass:MTLRenderPassDescriptor,drawable:MTLDrawable) throws{
        guard let encoder = self.configuration.commandbuffer?.makeRenderCommandEncoder(descriptor: renderPass) else { throw NSError(domain: "start encoder fail", code: 0, userInfo: nil)}
        
        encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(self.screenSize.w), height: Double(self.screenSize.h)
                                        , znear: -1, zfar: 1))
        
        encoder.setVertexBuffer(self.vertice, offset: 0, index: 0)
        
        
        let pipelinestate = try configuration.device.makeRenderPipelineState(descriptor: self.pipelineDescriptor)
        encoder.setRenderPipelineState(pipelinestate)
        encoder.setVertexBuffer(self.vertice, offset: 0, index: 0)
        encoder.setVertexBytes(&(self.screenSize), length: MemoryLayout<ScreenSize>.size, index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        if let indexb = self.indexVertice{
            encoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: rectangleIndex.count, indexType: .uint32, indexBuffer: indexb, indexBufferOffset: 0)
        }
        encoder.endEncoding()
        self.configuration.commandbuffer?.present(drawable)
    }
}
