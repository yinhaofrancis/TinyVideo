//
//  TinyVideoPlayer.swift
//  TinyVideo
//
//  Created by hao yin on 2021/3/2.
//

import UIKit
import AVFoundation

public class TinyVideoPlayer:AVPlayer{
    
    public var output = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA])
    
    public override func play() {
        super.play()
        self.currentItem?.add(self.output)
    }
    
    public func copyPixelbuffer()->CVPixelBuffer?{
        if let time = self.currentItem?.currentTime(), self.output.hasNewPixelBuffer(forItemTime: time){
            return self.output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil)
        }
        return nil
    }
    
}
