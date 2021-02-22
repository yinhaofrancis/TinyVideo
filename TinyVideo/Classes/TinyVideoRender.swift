//
//  TinyVideoRender.swift
//  TinyVideo
//
//  Created by hao yin on 2021/2/20.
//

import Metal

public class TinyComputer{
    public var device:MTLDevice
    public var queue:MTLCommandQueue
    public var defaultShader:MTLLibrary!
    public var commandbuffer:MTLCommandBuffer?
    public init() throws {
        let device = MTLCreateSystemDefaultDevice()
        guard let dev = device else { throw NSError(domain: "can't create metal context", code: 0, userInfo: nil) }
        self.device = dev
        guard let queue = dev.makeCommandQueue() else { throw NSError(domain: "can't create metal command queue", code: 0, userInfo: nil)}
        self.queue = queue
        try self.loadDefaultLibrary()
    }
    private func loadDefaultLibrary() throws{
        guard let url =  Bundle(for: TinyComputer.self).url(forResource: "default", withExtension: "metallib")?.path else { throw NSError(domain: "can't load default metal lib", code: 0, userInfo: nil) }
        self.defaultShader = try self.device.makeLibrary(filepath:url)
    }
    
    public func begin() throws {
        guard let commandbuffer = self.queue.makeCommandBuffer() else { throw NSError(domain: " can't create command buffer", code: 0, userInfo: nil)}
        self.commandbuffer = commandbuffer
    }
    
    public func commit() throws {
        self.commandbuffer?.commit()
        self.commandbuffer = nil
        self.commandbuffer?.waitUntilCompleted()
    }
    
    public func compute(name:String,threadGridSize:MTLSize? = nil,buffers:MTLBuffer ...) throws{
        
        guard let function = self.defaultShader.makeFunction(name: name) else {
            throw NSError(domain: "can't load function \(name)", code: 0, userInfo: nil)
        }
        let state = try self.device.makeComputePipelineState(function: function)
        guard let cmdBuffer = self.commandbuffer else {
            throw NSError(domain: "can't call begin", code: 0, userInfo: nil)
        }
        guard let encoder = cmdBuffer.makeComputeCommandEncoder() else {
            throw NSError(domain: "can't create command Encoder", code: 0, userInfo: nil)
        }
        encoder.setComputePipelineState(state)
        for i in 0 ..< buffers.count {
            encoder.setBuffer(buffers[i], offset: 0, index: i)
        }
        if let gsize = threadGridSize {
            let size = MTLSize(width: state.maxTotalThreadsPerThreadgroup, height: 1, depth: 1)
            encoder.dispatchThreadgroups(gsize, threadsPerThreadgroup: size)
        }
        encoder.endEncoding()
    }
    
    public func createBuffer(size:Int)->MTLBuffer?{
        return self.device.makeBuffer(length: size, options: .storageModeShared)
    }
}
