//
//  WebSourceDiskStorage.swift
//  test
//
//  Created by hao yin on 2021/4/13.
//

import Foundation
public struct WebSourceHeaderData:Codable{
    public var resourceType:String
    public var dataRanges: [ClosedRange<UInt64>]
    public var size:UInt64
}
public class WebSourceDiskStorage:WebSourceStorage {
    
    private var url:URL
    private var rw = UnsafeMutablePointer<pthread_rwlock_t>.allocate(capacity: 1)
    public required init(dir: URL, identify: String) throws  {
        self.url = dir.appendingPathComponent(identify, isDirectory: false)
        self.identify = identify
        if(!FileManager.default.fileExists(atPath: self.url.path)){
            FileManager.default.createFile(atPath: self.url.path, contents: nil, attributes: nil)
        }
        guard let r = self.readHandle else { throw NSError(domain: "open file error", code: 0, userInfo: nil) }
        do{
            let end = try WebSourceDiskStorage.seekToEnd(file: r)
            if(end > MemoryLayout<UInt64>.size){
                try WebSourceDiskStorage.seek(file: r, to: end - UInt64(MemoryLayout<UInt64>.size), size: 0)
                let data = r.readData(ofLength: MemoryLayout<UInt64>.size)
                let b = UnsafeMutablePointer<UInt8>.allocate(capacity: MemoryLayout<UInt64>.size)
                
                data.copyBytes(to: b, count: MemoryLayout<UInt64>.size)
                
                let u64p = b.withMemoryRebound(to: UInt64.self, capacity: 1) {$0}.pointee
                try WebSourceDiskStorage.seek(file: r, to: end - UInt64(MemoryLayout<UInt64>.size) - u64p , size: Int(u64p))
                let headerData = r.readData(ofLength: Int(u64p))
                self.header = try JSONDecoder().decode(WebSourceHeaderData.self, from: headerData)
            }
        }catch{
            throw NSError(domain: "open file error", code: 0, userInfo: nil)
        }
        pthread_rwlock_init(rw, nil)
    }
    public convenience init(identify:String) throws {
        let u = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        try self.init(dir:u,identify:identify)
    }
    
    public var writeHandle:FileHandle?{
        try? FileHandle(forWritingTo: self.url)
    }
    public var readHandle:FileHandle?{
        try? FileHandle(forReadingFrom: self.url)
    }
    
    var header:WebSourceHeaderData = WebSourceHeaderData(resourceType: "data", dataRanges: [], size: 0)
    
    public func saveData(data: Data, index: UInt64) throws {
        guard let w = self.writeHandle else { throw NSError(domain: "create file handle fail", code: 0, userInfo: nil) }
        do {
            pthread_rwlock_wrlock(self.rw)
            try WebSourceDiskStorage.seek(file:w ,to: index, size: data.count)
            if #available(iOS 13.4, *) {
                try self.writeHandle?.write(contentsOf: data)
            } else {
                self.writeHandle?.write(data)
            }
            self.header.dataRanges = WebSourceDiskStorage.mix(range: index...UInt64(data.count), ranges: self.dataRanges)
            try w.close()
            pthread_rwlock_unlock(self.rw)
        } catch  {
            try? w.close()
            pthread_rwlock_unlock(self.rw)
            throw error
        }
        
    }
    
    public class func fileLen(file:FileHandle)throws ->UInt64{
        if #available(iOS 13.4, *) {
            return try file.seekToEnd()
        } else {
            return file.seekToEndOfFile()
        }
    }
    public class func seek(file:FileHandle,to:UInt64,size:Int) throws {
        let len = try self.fileLen(file: file)
        if(to > len){
            try file.truncate(atOffset: to + UInt64(size))
            try file.seek(toOffset: to)
        }else{
            try file.seek(toOffset: to)
        }
    }
    public class func truncate(file:FileHandle,size:UInt64) throws{
        try file.truncate(atOffset: size)
    }
    public class func seekToEnd(file:FileHandle) throws->UInt64{
        if #available(iOS 13.4, *) {
            return try file.seekToEnd()
        } else {
            return file.seekToEndOfFile()
        }
    }
    public func loadData() -> Data? {
        guard let r = self.writeHandle else { return nil }
        pthread_rwlock_rdlock(self.rw)
        let data = r.readData(ofLength: Int(self.size))
        try? r.close()
        pthread_rwlock_unlock(self.rw)
        return data
    }
    
    public var identify: String
    
    public var size: UInt64{
        get{
            self.header.size
        }
        set{
            self.header.size = newValue
            guard let w = self.writeHandle else { return }
            pthread_rwlock_wrlock(self.rw)
            try? WebSourceDiskStorage.truncate(file:w,size:newValue)
            pthread_rwlock_unlock(self.rw)
        }
    }
    
    public var resourceType: String{
        get{
            self.header.resourceType
        }
        set{
            self.header.resourceType = newValue
        }
    }
    
    public var isComplete: Bool{
        return self.dataRanges.last?.lowerBound == 0 && self.dataRanges.last?.lowerBound == self.size - 1
    }
    
    public var dataRanges: [ClosedRange<UInt64>]{
        return self.header.dataRanges
    }
    public class func mix(range:ClosedRange<UInt64>,ranges:[ClosedRange<UInt64>])->[ClosedRange<UInt64>]{
        var sorted = ranges;
        
        sorted.sort { (a, b) -> Bool in
            a.lowerBound < b.lowerBound
        }
        var newOne = range
        var result = sorted.filter { (c) -> Bool in
            if newOne.canMerge(range: c){
                newOne = newOne.merge(range: c)
                return false
            }else{
                return true
            }
        }
        result.append(newOne)
        return result
    }
    deinit {
        self.saveHeader()
    }
    public func saveHeader(){
        if let headerd = try? JSONEncoder().encode(self.header) ,let write = self.writeHandle{
            
            do {
                pthread_rwlock_wrlock(self.rw)
                if #available(iOS 13.4, *) {
                    try write.seekToEnd()
                } else {
                    // Fallback on earlier versions
                    write.seekToEndOfFile()
                }
                write.write(headerd)
                let len = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
                len.pointee = UInt64(headerd.count)
                let data = Data(bytes: len, count: MemoryLayout<UInt64>.size)
                write.write(data)
                try write.close()
                pthread_rwlock_unlock(self.rw)
            } catch {
                pthread_rwlock_unlock(self.rw)
            }
        }
    }
    
}
extension ClosedRange where Bound == UInt64{
    public func canMerge(range:ClosedRange<UInt64>)->Bool{
        if(range.overlaps(self)){
            return true
        }else{
            if(range.lowerBound - self.upperBound == 1){
                return true
            }
            if(self.lowerBound - range.upperBound == 1){
                return true
            }
        }
        return false
    }
    
    public func merge(range:ClosedRange<UInt64>)->ClosedRange<UInt64>{
        return Swift.min(self.lowerBound, range.lowerBound) ... Swift.max(self.upperBound,range.upperBound)
    }
}
