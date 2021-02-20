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
}
