//
//  TinyVideoWebView.swift
//  TinyVideo_Example
//
//  Created by hao yin on 2021/3/27.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
import WebKit
import TinyVideo
import AVFoundation
let js = """
function hackWebVideo(){
    let  videos = document.getElementsByTagName("video");
    for (var i = 0; i < videos.length; i++){
        window.webkit.messageHandlers.videoUrl.postMessage(videos[i].src);
    }
}
function downloadWebVideo(){
    let  videos = document.getElementsByTagName("video");
    for (var i = 0; i < videos.length; i++){
        window.webkit.messageHandlers.download.postMessage(videos[i].src);
    }
}

function hackiframe(){
    let  iframes = document.getElementsByTagName("iframe");
    for (var i = 0; i < iframes.length; i++){
        window.webkit.messageHandlers.iframeUrl.postMessage(iframes[i].src);
    }
}

"""

public class TinyVideoWebView: WKWebView {
    
    public typealias  HandleVideo = (TinyVideoResource<VideoDiskCache>)->Void
    
    public typealias  HandleUrl = (URL)->Void
    
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window != nil{
            self.configuration.allowsInlineMediaPlayback = true;
            self.addHandle(name: "videoUrl") { (msg) in
                
                guard let url = URL(string: msg.body as! String) else { return }
                
                guard let resource = TinyVideoResourceManager.shared.loadResource(url: url, identify: "") else { return }
                
                self.handleVideoAsset?(resource)
            }
            self.addHandle(name: "iframeUrl") { (msg) in
                guard let url = URL(string: msg.body as! String) else { return }
                self.handleIframe?(url)
            }
            self.addHandle(name: "download") { (msg) in
                guard let url = URL(string: msg.body as! String) else { return }
                self.handleDownload?(url)
            }
            self.addScript(code: js)
        }
    }
    
    public func addScript(code:String){
        let script = WKUserScript(source: code, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        self.configuration.userContentController.addUserScript(script)
    }
    public func addHandle(name:String,callback:@escaping (WKScriptMessage)->Void){
        let  msgHandle = TinyWebMessageHandler(name: name, callback: callback)
        self.configuration.userContentController.removeScriptMessageHandler(forName: name)
        self.configuration.userContentController.add(msgHandle, name: name)
    }
    public func hackWebVideo(){
        self.evaluateJavaScript("hackWebVideo()") { (a, e) in
            guard let error = e else { return }
            print(error)
        }
    }
    public func hackIframe(){
        self.evaluateJavaScript("hackiframe()") { (a, e) in
            guard let error = e else { return }
            print(error)
        }
    }
    public func downloadWebVideo(){
        self.evaluateJavaScript("downloadWebVideo()") { (a, e) in
            guard let error = e else { return }
            print(error)
        }
    }
    public var handleVideoAsset:HandleVideo?
    public var handleIframe:HandleUrl?
    public var handleDownload:HandleUrl?
}

public class TinyWebMessageHandler:NSObject,WKScriptMessageHandler{
    
    public let callback:(WKScriptMessage)->Void
    public let name:String
    public init(name:String,callback:@escaping (WKScriptMessage)->Void) {
        self.callback = callback
        self.name = name
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        self.callback(message)
    }
    
}
