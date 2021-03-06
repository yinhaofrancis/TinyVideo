//
//  TinyVideoRender.swift
//  TinyVideo
//
//  Created by hao yin on 2021/2/20.
//

import Metal
import simd
import MetalPerformanceShaders
import MetalKit

public class TinyTextureRender {
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
        
        pipelineDesc.vertexDescriptor = self.vertexDescriptor;
    }
    
    public var ratio:Float = 1{
        didSet{
            if(oldValue != self.ratio){
                self.vertice = nil;
            }
        }
    }
    public var screenSize:CGSize = CGSize(width: 320, height: 480)

    public var rectangle:[vertex]{
        let w:Float = 1
        let h = Float(screenSize.width) / Float(screenSize.height) * ratio;
        
        return [
            vertex(location: simd_float4(-w, h, 0, 1), texture: simd_float2(0, 0)),
            vertex(location: simd_float4(w, h, 0, 1), texture: simd_float2(1, 0)),
            vertex(location: simd_float4(w, -h, 0, 1), texture: simd_float2(1, 1)),
            vertex(location: simd_float4(-w, -h, 0, 1), texture: simd_float2(0, 1))
        ]
    }
    public var vertice:MTLBuffer?
    
    
    public lazy var indexVertice:MTLBuffer? = {
        return self.configuration.device.makeBuffer(bytes: rectangleIndex, length: rectangleIndex.count * MemoryLayout<UInt32>.size, options: .storageModeShared)
    }()
    public lazy var samplerState:MTLSamplerState? = {
        let sample = MTLSamplerDescriptor()
        sample.mipFilter = .linear
        sample.magFilter = .linear
        sample.minFilter = .linear
        return self.configuration.device.makeSamplerState(descriptor: sample)
    }()
    public lazy var vertexDescriptor:MTLVertexDescriptor = {
        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float4
        vd.attributes[0].offset = 0;
        vd.attributes[0].bufferIndex = 0;
        vd.attributes[1].format = .float2
        vd.attributes[1].offset = MemoryLayout<simd_float4>.stride
        vd.attributes[1].bufferIndex = 0
        vd.layouts[0].stride = MemoryLayout<vertex>.stride
        vd.layouts[0].stepRate = 1;
        vd.layouts[0].stepFunction = .perVertex
        return vd
    }()
    public var rectangleIndex:[UInt32]{
        [
            0,3,1,2
        ]
    }
    
    
    public func render(image:CGImage,drawable:CAMetalDrawable) throws{
        
        let text = try MTKTextureLoader.init(device: self.configuration.device).newTexture(cgImage: image, options: nil)
        try self.render(texture: text, drawable: drawable)
    }
    
    public func render(texture:MTLTexture,drawable:CAMetalDrawable) throws{
        let renderPass = MTLRenderPassDescriptor()
        if(self.vertice == nil){
            self.vertice = self.configuration.device.makeBuffer(bytes: rectangle, length: MemoryLayout<vertex>.stride * rectangle.count, options: .storageModeShared)
        }
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].texture = drawable.texture
        
        guard let encoder = self.configuration.commandbuffer?.makeRenderCommandEncoder(descriptor: renderPass) else { throw NSError(domain: "start encoder fail", code: 0, userInfo: nil)}
        
        encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(self.screenSize.width), height: Double(self.screenSize.height)
                                        , znear: -1, zfar: 1))
        let pipelinestate = try configuration.device.makeRenderPipelineState(descriptor: self.pipelineDescriptor)
        encoder.setRenderPipelineState(pipelinestate)
        encoder.setVertexBuffer(self.vertice, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(self.samplerState, index: 0)
        if let indexb = self.indexVertice{
            encoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: rectangleIndex.count, indexType: .uint32, indexBuffer: indexb, indexBufferOffset: 0)
        }
        encoder.endEncoding()
        self.configuration.commandbuffer?.present(drawable)
    }
}


