//
//  TinyAudioNode.swift
//  TinyAudio
//
//  Created by hao yin on 2021/3/26.
//

import Foundation
import AudioToolbox
import AVFoundation
public protocol AudioOutputProtocol:class {
    
    func handleAudioBuffer(node:AudioNodeProtocol, buffer:TinyAudioBuffer)
    
    func handleStreamDescription(node:AudioNodeProtocol,description:AudioStreamBasicDescription)
    
}

public protocol AudioInputProtocol:class {
    
    var description: AudioStreamBasicDescription { get }
    
    func getNextAudioBuffer()->TinyAudioBuffer?
    
}

public protocol AudioNodeProtocol:class {
    var isRuning:Bool { get }

}

public protocol AudioProducerProtocol:AudioNodeProtocol {
    
    
    
    var output:AudioOutputProtocol? { get }
    
    
    
}


public protocol AudioConsumerProtocol:AudioNodeProtocol {
    
    var input:AudioInputProtocol? { get }
    
}

public struct TinyAudioBuffer{
    public var data:Data
    public var time:AudioTimeStamp
    public var audioStreamPacketDescription:AudioStreamPacketDescription?
}


public class TinyAudioMemoryCache:AudioOutputProtocol,AudioInputProtocol{
    public func getNextAudioBuffer() -> TinyAudioBuffer? {
        
        if(self.buffers.count > 0){
            return self.buffers.remove(at: 0)
        }
        return nil
    }

    
    public var outPut: AudioOutputProtocol?
        
    public var description:AudioStreamBasicDescription = AudioStreamBasicDescription()
    
    
    public var buffers:[TinyAudioBuffer] = []
    
    public func handleAudioBuffer(node: AudioNodeProtocol, buffer:TinyAudioBuffer) {
        self.buffers.append(buffer)
    }
    
    public func handleStreamDescription(node: AudioNodeProtocol, description: AudioStreamBasicDescription) {
        self.description = description
    }
    
    
}
