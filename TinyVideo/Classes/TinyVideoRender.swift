//
//  TinyVideoRender.swift
//  TinyVideo
//
//  Created by hao yin on 2021/2/20.
//

import Metal
import simd
import MetalPerformanceShaders




public class TinyRender {
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
    public var screenSize:CGSize = CGSize(width: 320, height: 480)
    
    public var ortho:float4x4{
        return float4x4(columns: (
            simd_float4(1 / Float(self.screenSize.width), 0, 0, 0),
            simd_float4(0, 1 / Float(self.screenSize.height), 0, 0),
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
            vertex(location: simd_float4(-0.6, 0.6, 0, 1), texture: simd_float2(0, 0)),
            vertex(location: simd_float4(0.5, 0.5, 0, 1), texture: simd_float2(1, 0)),
            vertex(location: simd_float4(0.5, -0.5, 0, 1), texture: simd_float2(1, 1)),
            vertex(location: simd_float4(-0.5, -0.5, 0, 1), texture: simd_float2(0, 1))
        ]
    }
    public lazy var vertice:MTLBuffer? = {
        return self.configuration.device.makeBuffer(bytes: rectangle, length: MemoryLayout<vertex>.stride * rectangle.count, options: .storageModeShared)
    }()
    
    
    public lazy var indexVertice:MTLBuffer? = {
        return self.configuration.device.makeBuffer(bytes: rectangleIndex, length: rectangleIndex.count * MemoryLayout<UInt32>.size, options: .storageModeShared)
    }()
    public var rectangleIndex:[UInt32]{
        [
            0,3,1,2
        ]
    }
    public func render(texture:MTLTexture,drawable:CAMetalDrawable) throws{
        
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].texture = drawable.texture
        
        guard let encoder = self.configuration.commandbuffer?.makeRenderCommandEncoder(descriptor: renderPass) else { throw NSError(domain: "start encoder fail", code: 0, userInfo: nil)}
        
        encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(self.screenSize.width), height: Double(self.screenSize.height)
                                        , znear: -1, zfar: 1))
        
        encoder.setVertexBuffer(self.vertice, offset: 0, index: 0)
        
        
        let pipelinestate = try configuration.device.makeRenderPipelineState(descriptor: self.pipelineDescriptor)
        encoder.setRenderPipelineState(pipelinestate)
        encoder.setVertexBuffer(self.vertice, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        if let indexb = self.indexVertice{
            encoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: rectangleIndex.count, indexType: .uint32, indexBuffer: indexb, indexBufferOffset: 0)
        }
        encoder.endEncoding()
        self.configuration.commandbuffer?.present(drawable)
    }
}
