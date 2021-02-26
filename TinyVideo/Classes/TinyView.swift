//
//  File.swift
//  TinyVideo
//
//  Created by hao yin on 2021/2/25.
//

import Metal
import MetalKit
import Foundation
import simd


public struct Point{
    public var x:Float
    public var y:Float
    public init(x:Float, y:Float){
        self.x = x
        self.y = y
    }
}
public struct Size{
    public var w:Float
    public var h:Float
    public init(w:Float, h:Float){
        self.w = w
        self.h = h
    }
}
public struct Rect{
    public var location:Point
    public var size:Size
    public init(x:Float,y:Float,w:Float,h:Float){
        self.location = Point(x:x,y:y)
        self.size = Size(w:w,h:h)
    }
}

public protocol TinyLayer{
    var frame:Rect { get set }
    var bound:Rect { get set }
    var zPosion:Float { get set }
    var backgroundColor:simd_float4 { get set }
    
    var pipelineDescriptor:MTLRenderPipelineDescriptor { get }
}

public struct vertex{
    public var location: simd_float4
    public var texture: simd_float2
    public init(location:simd_float4,texture:simd_float2){
        self.location = location
        self.texture = texture
    }
}

extension TinyLayer{
    public var vertice:[vertex]{
        let bound = UIScreen.main.nativeBounds
        let x1 = self.frame.location.x / Float(bound.size.width) * 2
        let y1 = self.frame.location.y / Float(bound.size.height) * 2
        
        let w1 = self.frame.size.w / Float(bound.size.width) * 2
        let h1 = self.frame.size.h / Float(bound.size.height) * 2
        
        let v = [
            vertex(location: simd_float4(x: x1 - 1, y: y1 - 1, z: zPosion,w: 1), texture: simd_float2(x: 0, y: 0)),
            vertex(location: simd_float4(x: x1 - 1 + w1, y: y1 - 1, z: zPosion,w: 1), texture: simd_float2(x: 1, y: 0)),
            vertex(location: simd_float4(x: x1 - 1, y: y1 - 1 + h1, z: zPosion,w: 1), texture: simd_float2(x: 0, y: 1)),
            vertex(location: simd_float4(x: x1 - 1 + w1, y: y1 - 1 + h1, z: zPosion,w: 1), texture: simd_float2(x: 1, y: 1)),
        ]
        return v
    }
    public func verticsBuffer(device:MTLDevice)->MTLBuffer?{
        return device.makeBuffer(bytes: self.vertice, length: MemoryLayout<vertex>.stride * vertice.count, options: .storageModeShared)
    }
    
    public func indexVertice(device:MTLDevice)->MTLBuffer? {
        return device.makeBuffer(bytes: rectangleIndex, length: rectangleIndex.count * MemoryLayout<UInt32>.stride, options: .storageModeShared)
    }
    public var rectangleIndex:[UInt32]{
        [
            0,1,2,3
        ]
    }
}

public struct TinyView:TinyLayer{
    public var pipelineDescriptor: MTLRenderPipelineDescriptor
    
    public var frame: Rect
    
    public var bound: Rect
    
    public var zPosion: Float = 1
    
    public var backgroundColor: simd_float4 = simd_float4(x: 1, y: 1, z: 1, w: 1)
    
    public init(frame:Rect,configuration:TinyMetalConfiguration,vertex:String,fragment:String) {
        self.frame = frame
        bound = Rect(x: 0, y: 0, w: frame.size.w, h: frame.size.h)
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = configuration.shaderLibrary.makeFunction(name: vertex)
        pipelineDesc.fragmentFunction = configuration.shaderLibrary.makeFunction(name: fragment)
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        self.pipelineDescriptor = pipelineDesc
    }
}

public class TinyRender{
    public var configuration:TinyMetalConfiguration
    public var w:Float
    public var h:Float
    public init(configuration:TinyMetalConfiguration,w:Float,h:Float) {
        self.configuration = configuration
        self.w = w
        self.h = h
    }
    public func render(layer:TinyLayer,drawable:CAMetalDrawable) throws{
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].texture = drawable.texture
        guard let encoder = self.configuration.commandbuffer?.makeRenderCommandEncoder(descriptor: renderPass) else { throw NSError(domain: "start encoder fail", code: 0, userInfo: nil)}
        encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(w), height: Double(h)
                                        , znear: -1000, zfar: 1000))
        
        encoder.setVertexBuffer(layer.verticsBuffer(device: self.configuration.device), offset: 0, index: 0)
        let pipelinestate = try configuration.device.makeRenderPipelineState(descriptor: layer.pipelineDescriptor)
        encoder.setRenderPipelineState(pipelinestate)
        
        if let indexb = layer.indexVertice(device: self.configuration.device){
            encoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: layer.rectangleIndex.count, indexType: .uint32, indexBuffer: indexb, indexBufferOffset: 0)
        }
        encoder.endEncoding()
        self.configuration.commandbuffer?.present(drawable)
        
    }
}
