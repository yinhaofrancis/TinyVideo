//
//  TinyVideoTrack.swift
//  TinyVideo_Example
//
//  Created by hao yin on 2021/2/17.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

extension CMSampleBuffer{
    public var currentTime:CMTime{
        if #available(iOS 13.0, *) {
            return self.presentationTimeStamp
        } else {
            return CMSampleBufferGetPresentationTimeStamp(self)
        }
    }
}

public protocol TinyVideoTrack{
    
    func nextSampleBuffer(current: CMTime) -> CVPixelBuffer?
    
    func finish()
    
    func ready()
    
    var size:CGSize { get }
    
    var during:CMTime { get }
    
    var audioMix:AVAudioMix? { get }
    
    var startTime:CMTime { get }
    
    var transform:CGAffineTransform { get }
    
}

public class TinyAssetVideoTrack:TinyVideoTrack{
    
    public var transform: CGAffineTransform{
        self.videoOutput.track.preferredTransform
    }
    
    public var audioMix: AVAudioMix?{
        return self.audioOutput.audioMix
    }
    
    public func ready() {
        self.reader.startReading()
    }
    
    
    public func finish() {
        self.videoOutput.markConfigurationAsFinal()
    }
    
    
    var last:CMSampleBuffer?
    var next:CMSampleBuffer?
    var minLen:CMTime{
        let len = CMTime(seconds: 10, preferredTimescale: .max)
        if len < self.during{
            return len
        }else{
            return self.during
        }
    }
    var currentRange:CMTimeRange
    var reader:AVAssetReader
    
    public func nextSampleBuffer(current: CMTime) -> CVPixelBuffer? {
        if(current > self.during || current < .zero){
            return nil
        }
        let time:CMTime = current - self.startTime
        if self.last == nil{
            self.last = self.videoOutput.copyNextSampleBuffer()
        }
        
        if self.next == nil{
            self.next = self.videoOutput.copyNextSampleBuffer()
        }
        if let l = self.last , let n = self.next {
            if l.currentTime <= time && n.currentTime > time{
                return CMSampleBufferGetImageBuffer(l)
            }else{
                self.last = n
                self.next = self.videoOutput.copyNextSampleBuffer()
                return self.nextSampleBuffer(current: current)
            }
        }else {
            return nil
        }
    }
    
    public var during: CMTime{
        self.videoOutput.track.asset?.duration ?? .zero
    }
    
    public let videoOutput:AVAssetReaderTrackOutput
    
    public let audioOutput:AVAssetReaderAudioMixOutput
    
    public var size: CGSize{
        return self.videoOutput.track.naturalSize
    }
    
    public init(asset:AVAsset) throws {
        self.reader = try AVAssetReader(asset: asset)
        
        guard let track = asset.tracks(withMediaType: .video).first else { throw NSError(domain: "no video", code: 0, userInfo: nil)}
        let videoSetting:[String:Any] = [
            kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA
        ]
        self.videoOutput = AVAssetReaderTrackOutput(track: track, outputSettings: videoSetting)
//        self.videoOutput.supportsRandomAccess = true

        self.reader.add(self.videoOutput)
        
        let atrack = asset.tracks(withMediaType: .audio)
        
        
        let audioSetting:[String:Any] = [AVFormatIDKey:kAudioFormatLinearPCM]

        self.audioOutput = AVAssetReaderAudioMixOutput(audioTracks: atrack, audioSettings: audioSetting)
//        self.audioOutput.supportsRandomAccess = true
       
        self.currentRange = CMTimeRange(start: .zero, duration: .zero)
    }
    
    public var startTime:CMTime = .zero
}


public class TinyAudioMixer{
    
    public var param:[AVMutableAudioMixInputParameters] = []
    public func addAudioTrack(track:AVAssetTrack){
        let a = AVMutableAudioMixInputParameters(track: track)
        self.param.append(a)
    }
    public func export(){
        let all = AVMutableAudioMix()
        all.inputParameters = param
    }
}


public class TinyVideoContext{
    public var cgContext:CGContext
    public var ciContext:CIContext
    public typealias DrawFrameCallBack = (CMTime,TinyVideoContext)->Void
    public init(size:CGSize){
        self.cgContext = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: Int(4 * size.width), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        self.ciContext = CIContext()
    }
    public func drawImage(pixel:CIImage,frame:CGRect,filter:TinyVideoFilter? = nil){
        var img:CIImage? = pixel
        if let f = filter{
            img = f.filter(img: pixel)
        }
        if img == nil{
            img = pixel
        }
        if let cgimg = self.ciContext.createCGImage(img!, from: img!.extent){
            self.cgContext.draw(cgimg, in: frame)
        }
    }
    public func exportFrame(time:CMTime,callback: DrawFrameCallBack)->CGImage?{
        callback(time,self)
        return self.cgContext.makeImage()
    }
}
public protocol TinyVideoFilter{
    func filter(img:CIImage) -> CIImage?
}
