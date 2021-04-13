//
//  WebImage.swift
//  test
//
//  Created by hao yin on 2021/4/13.
//

import UIKit

public protocol WebSourceStorage{
    func saveData(data:Data,index:UInt64) throws
    func loadData()->Data?
    var identify:String { get }
    init(dir:URL,identify:String) throws
    var size:UInt64 { get set }
    var resourceType:String { get set }
    var isComplete:Bool { get }
    var dataRanges:[ClosedRange<UInt64>] {get}
    
}

public protocol WebImageDisplay:class{
    func render(image:CGImage?)
}

public class WebImageObject:Hashable{
    
    public static func == (lhs: WebImageObject, rhs: WebImageObject) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    public var display:WebImageDisplay?
    
    public var hasher:Hasher = Hasher()
    
    public func hash(into hasher: inout Hasher) {
        hasher = self.hasher
    }
}


public class WebImageManager{

    
    public func register(obj:WebImageObject,identify:String){

        self.imageDisplayMap = self.imageDisplayMap.filter{
            $0.value != obj
        }
        self.imageDisplayMap[identify] = obj
    }

    private var imageDisplayMap:[String:WebImageObject] = [:]
}

public class WebSourceDownload{
    static let session:URLSession = URLSession(configuration: .default)
    
}
