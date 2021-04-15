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
    func complete(range:ClosedRange<UInt64>)->Bool
    var percent:Float { get }
    var dataRanges:[ClosedRange<UInt64>] {get}
    func delete() throws
    func close() throws
    var dataHeader:WebSourceHeaderData { get set }
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
