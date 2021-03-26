//
//  TinyAudioPlayer.swift
//  TinyAudio
//
//  Created by hao yin on 2021/3/26.
//

import Foundation
import AudioToolbox
import AVFoundation


public class TinyAudioPlayer:AudioConsumerProtocol{
    
    var threadQueue:DispatchQueue =  DispatchQueue(label: "TinyAudioPlayer.threadQueue")
    
    public weak var input: AudioInputProtocol?
    
    var workingBuffers:Set<AudioQueueBufferRef> = Set()
    
    var description:AudioStreamBasicDescription = AudioStreamBasicDescription()
    
    private func createBuffer(buffer:TinyAudioBuffer)->AudioQueueBufferRef?{
        var abuffer:AudioQueueBufferRef?
        let size:UInt32 = UInt32(buffer.data.count)
        AudioQueueAllocateBuffer(self.audioQueue!, size, &abuffer)
        guard let audio = abuffer else { return nil }
        audio.pointee.mAudioDataByteSize = UInt32(buffer.data.count)
        let temp = UnsafeMutablePointer<UInt8>.allocate(capacity: buffer.data.count)
        buffer.data.copyBytes(to: temp, count: buffer.data.count)
        memcpy(audio.pointee.mAudioData, temp, buffer.data.count)
        temp.deallocate()
        return audio
    }
    public var isRuning: Bool{
        var c:UInt32 = 0
        var data:UInt32 = 0
        AudioQueueGetProperty(self.audioQueue!, kAudioQueueProperty_IsRunning, &data, &c);
        return data != 0
    }
    
    public var audioQueue:AudioQueueRef?
        

    public func start() {
        
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        guard let inputObj = self.input else { return }
        if self.audioQueue == nil{
            self.description = inputObj.description
            var status = AudioQueueNewOutputWithDispatchQueue(&self.audioQueue, &self.description, 0, self.threadQueue) { (aQueue, buffer) in
                self.workingBuffers.remove(buffer)
                AudioQueueFreeBuffer(aQueue, buffer)
                if self.isRuning == true {
                    self.enqueueBuffer(inputObj: inputObj, aQueue: aQueue)
                }
            }
            
            if status != errSecSuccess{
                print("player start fail")
            }
            
            
            
            status =  AudioQueueStart(self.audioQueue!, nil)
            self.enqueueBuffer(inputObj: inputObj, aQueue: self.audioQueue!)
            self.enqueueBuffer(inputObj: inputObj, aQueue: self.audioQueue!)
            self.enqueueBuffer(inputObj: inputObj, aQueue: self.audioQueue!)
            if status != errSecSuccess{
                print("player start fail")
            }
        }else{
            
            AudioQueueStart(self.audioQueue!, nil)
            if self.workingBuffers.count == 0{
                self.enqueueBuffer(inputObj: inputObj, aQueue: self.audioQueue!)
                self.enqueueBuffer(inputObj: inputObj, aQueue: self.audioQueue!)
                self.enqueueBuffer(inputObj: inputObj, aQueue: self.audioQueue!)
            }
        }
        
    }
    
    func enqueueBuffer(inputObj:AudioInputProtocol,aQueue:AudioQueueRef){
        guard let a = inputObj.getNextAudioBuffer() else { return }
        guard let newbuffer =  self.createBuffer(buffer: a) else { return }
        AudioQueueEnqueueBuffer(aQueue, newbuffer, 0, nil)
        self.workingBuffers.insert(newbuffer);
    }
    
    public func end() {
        AudioQueueStop(self.audioQueue!,true)
    }
    
    public func pause() {
        AudioQueuePause(self.audioQueue!)
    }
    deinit {
        AudioQueueDispose(self.audioQueue!, true)
    }
    
}
