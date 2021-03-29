//
//  TinyVideoWebView.swift
//  TinyVideo_Example
//
//  Created by hao yin on 2021/3/27.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
import WebKit
public class TinyVideoWebView: WKWebView {
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window != nil{
            self.addHandle(name: "videoUrl") { (msg) in
                print(msg.body)
            }
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
