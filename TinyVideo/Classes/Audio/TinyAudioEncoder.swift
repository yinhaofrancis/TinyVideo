//
//  TinyAudioEncoder.swift
//  TinyVideo
//
//  Created by hao yin on 2021/3/31.
//

import AudioToolbox

public let TinyAudioEncoderOutputBufferSize:UInt32 = 32 * 1024

public class TinyAudioEncoder:AudioOutputProtocol,AudioProducerProtocol{
    public func handleStreamFinish() {
        self.output?.handleStreamFinish()
    }
    public var output: AudioOutputProtocol?{
        willSet{
            newValue?.handleStreamDescription(node: self, description: self.description)
        }
    }
    weak var ws:TinyAudioEncoder?
    public var bitRate:UInt32{
        get{
            if let cv = self.convert{
                var size:UInt32 = 0
                var rat:UInt32 = 0
                AudioConverterGetProperty(cv, kAudioConverterEncodeBitRate, &size, &rat)
                return size
            }
            return 0
        }
        set{
            if let cv = self.convert{
                var v = newValue
                let s = AudioConverterSetProperty(cv, kAudioConverterEncodeBitRate, UInt32(MemoryLayout<UInt32>.size), &v)
                if s != noErr{
                    print("error \(s)")
                }
            }
            
        }
    }
    public var maximumOutputPacketSize:UInt32{
        guard let cv = self.convert else { return 0 }
        var size:UInt32 = 0
        var sizePerPacket:UInt32 = 0
        AudioConverterGetProperty(cv,kAudioConverterPropertyMaximumOutputPacketSize,&size,&sizePerPacket);
        return sizePerPacket
    }
    public var outputBufferSize:UInt32{
        return self.description.mBytesPerPacket == 0 ? (self.maximumOutputPacketSize == 0 ? TinyAudioEncoderOutputBufferSize : self.maximumOutputPacketSize) : self.description.mBytesPerPacket
    }
    public var queue:DispatchQueue = DispatchQueue(label: "TinyAudioEncoder")
    public var isRuning: Bool{
        self.convert != nil
    }
    
    public var convert:AudioConverterRef?
    
    public init(description: AudioStreamBasicDescription = TinyAudioEncoder.defaultAACDescription) {
        self.description = description
        self.ws = self
    }
    public var description: AudioStreamBasicDescription
    
    public var buffer:TinyAudioBuffer?
    var sem:DispatchSemaphore = DispatchSemaphore(value: 1)
    
    //输入
    public func handleAudioBuffer(node: AudioNodeProtocol, buffer: TinyAudioBuffer) {
        if self.buffer == nil{
            self.buffer = buffer
        }else{
            self.buffer?.data.append(buffer.data)
        }
        guard let bf = self.buffer else { return }
        if(bf.data.count > valuePack){
            self.convertBuffer()
        }
    }
    public func convertBuffer(){
        if self.convert == nil{
            return
        }
        var packSize:UInt32 = self.outputBufferSize / self.maximumOutputPacketSize
        let outer = UnsafeMutableRawPointer.allocate(byteCount: Int(self.outputBufferSize), alignment: 1)
        memset(outer, 0, Int(self.outputBufferSize));
        
        var buffer = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: self.description.mChannelsPerFrame, mDataByteSize: TinyAudioEncoderOutputBufferSize, mData: outer))
        var disc = AudioStreamPacketDescription()
        let status = AudioConverterFillComplexBuffer(self.convert!, { (cv, size, buffer, desc, ws) -> OSStatus in
            guard let s = ws?.assumingMemoryBound(to: TinyAudioEncoder.self).pointee else { return -1 }
            
            s.copyBuffer(audiobuffer: buffer)
            size.pointee = 1
            return noErr
        }, &self.ws, &packSize, &buffer, &disc)
        if status != noErr{
            outer.deallocate()
            return
        }
        
        guard let bufferData = buffer.mBuffers.mData else { outer.deallocate();return }
        let tinyBuffer = TinyAudioBuffer(data: Data(bytes: bufferData, count: Int(buffer.mBuffers.mDataByteSize)), time: self.buffer?.time ?? AudioTimeStamp(), audioStreamPacketDescription: disc)
        self.output?.handleAudioBuffer(node: self, buffer: tinyBuffer)
        self.buffer = nil
        outer.deallocate()
    }
    public func handleStreamDescription(node: AudioNodeProtocol, description: AudioStreamBasicDescription) {
        var source = description
        let cl = self.createAudioClass(type: self.description.mFormatID)
        self.description.mSampleRate = description.mSampleRate
        let c = AudioConverterNewSpecific(&source, &self.description, UInt32(cl.count), cl, &self.convert)
        if(c != noErr){
            print("error \(c)")
        }
    }
    
    public func createAudioClass(type:AudioFormatID) -> [AudioClassDescription] {
        return [
            AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: type, mManufacturer: kAppleSoftwareAudioCodecManufacturer),
            AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: type, mManufacturer: kAppleHardwareAudioCodecManufacturer),
        ]
    }
    
    public func copyBuffer(audiobuffer:UnsafeMutablePointer<AudioBufferList>){
        
        guard let bf = self.buffer else { return }
        
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: bf.data.count)
        bf.data.copyBytes(to: ptr, count: bf.data.count)
        audiobuffer.pointee.mBuffers.mData = UnsafeMutableRawPointer(ptr)
        audiobuffer.pointee.mBuffers.mDataByteSize = UInt32(bf.data.count)
        audiobuffer.pointee.mNumberBuffers = 1
    }
    
    
    public static var defaultAACDescription:AudioStreamBasicDescription {
        
        AudioStreamBasicDescription(mSampleRate: 48000,
                                               mFormatID: kAudioFormatMPEG4AAC,
                                               mFormatFlags: 0,
                                               mBytesPerPacket: 0,
                                               mFramesPerPacket: 1024,
                                               mBytesPerFrame: 0,
                                               mChannelsPerFrame: 2,
                                               mBitsPerChannel: 0,
                                               mReserved: 0)
    }
    
    public func finish(){
        guard let bf = self.buffer else { return  }
        if bf.data.count > 0{
            if bf.data.count < valuePack{
                self.buffer?.data.append(Data(repeating: 0, count: Int(valuePack) - bf.data.count))
            }
            self.convertBuffer()
        }
    }
    public func invaild(){
        guard let c = self.convert else { return  }
        AudioConverterDispose(c)
        self.ws = nil
    }
    public let valuePack:UInt32 = 2 * 1024
}
