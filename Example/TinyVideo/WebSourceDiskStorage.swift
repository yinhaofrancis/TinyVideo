//
//  WebSourceDiskStorage.swift
//  test
//
//  Created by hao yin on 2021/4/13.
//

import Foundation
import CommonCrypto

extension WebSourceStorage{
    public static func digest(name:String)->String?{
        guard let data = name.data(using: .utf8) else { return nil }
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        data.copyBytes(to: p, count: data.count)
        let r = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5(p, CC_LONG(data.count), r)
        let d = Data(bytes: r, count: Int(CC_MD5_DIGEST_LENGTH)).base64EncodedString()
        p.deallocate()
        r.deallocate()
        return d
    }
}

public struct WebSourceHeaderData:Codable,CustomDebugStringConvertible{
    public var debugDescription: String{
        return
            """
            {
                resourceType:\(resourceType),
                dataRanges:\(dataRanges),
                size:\(size),
                lastRequest:\(self.lastRequestDate ?? "空"),
                expires:\(self.expiresDate ?? "空"),
                Etag:\(self.etag ?? "空"),
            }
            """
    }
    
    public var resourceType:String
    public var dataRanges: [ClosedRange<UInt64>]
    public var noDataRanges:[ClosedRange<UInt64>]{
        if(dataRanges.count == 0){
            if(self.size > 0){
                return [0...0]
            }else{
                return [0...self.size - 1]
            }
        }else{
            return (0...self.size - 1).except(items: self.dataRanges)
        }
    }
    public var size:UInt64
    public var lastRequest:Date?
    public var expires:Date?
    public var etag:String?
    public var cookie:String?
    public var status:Int
    
    public var lastRequestDate:String?{
        get{
            guard let date = lastRequest else { return nil }
            return WebSourceHeaderData.format.string(from: date)
        }
        set{
            guard let d = newValue else { self.lastRequest = nil;return }
            lastRequest = WebSourceHeaderData.format.date(from: d)
        }
    }
    public var expiresDate:String?{
        get{
            guard let date = expires else { return nil }
            return WebSourceHeaderData.format.string(from: date)
        }
        set{
            guard let d = newValue else { self.expires = nil;return }
            expires = WebSourceHeaderData.format.date(from: d)
        }
    }
    public static var format:DateFormatter = {
        let d = DateFormatter()
        d.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return d
    }()
}

public class WebSourceDiskStorage:WebSourceStorage,CustomDebugStringConvertible {
    
    public var identify: String
    
    private var url:URL
    
    private var rw = UnsafeMutablePointer<pthread_rwlock_t>.allocate(capacity: 1)
    
    private var header:WebSourceHeaderData = WebSourceHeaderData(resourceType: "data", dataRanges: [], size: 0, lastRequest: Date(), status: 0)
    
    public var dataHeader: WebSourceHeaderData{
        get{
            return self.header
        }
        set{
            self.header = newValue
        }
    }

    public required init(dir: URL, identify: String) throws  {
        self.url = dir.appendingPathComponent(identify, isDirectory: false)
        self.identify = identify
        pthread_rwlock_init(rw, nil)
        if(!FileManager.default.fileExists(atPath: self.url.path)){
            FileManager.default.createFile(atPath: self.url.path, contents: nil, attributes: nil)
        }
        try self.loadHeader()
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
    
    //debug
    public var debugDescription: String{
        """
        {
            header:\(self.header),
            url:\(self.url),
            identify:\(self.identify)
        }
        """
    }
    
    public var size: UInt64{
        get{
            self.header.size
        }
        set{
            self.header.size = newValue
            guard let w = self.writeHandle else { return }
            pthread_rwlock_wrlock(self.rw)
            try? WebSourceDiskStorage.truncate(file:w,size:newValue)
            try? WebSourceDiskStorage.close(file: w)
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
        if(self.size == 0){
            return false
        }
        return self.dataRanges.last?.lowerBound == 0 && self.dataRanges.last?.upperBound == self.size - 1
    }
    public func complete(range: ClosedRange<UInt64>) ->Bool{
        for i in self.dataRanges{
            if(i.cover(to: range)){
                return true
            }
        }
        return false
    }
    public var dataRanges: [ClosedRange<UInt64>]{
        return self.header.dataRanges
    }
    public var percent: Float{
        let dataUse = self.dataRanges.reduce(0) { (last, current) -> UInt64 in
            return last + current.upperBound - current.lowerBound + 1
        }
        return Float(dataUse) / Float(self.size)
    }
    //instance method
    public func saveData(data: Data, index: UInt64) throws {
        guard let w = self.writeHandle else {
            throw NSError(domain: "create file handle fail", code: 0, userInfo: nil)
        }
        do {
            pthread_rwlock_wrlock(self.rw)
            try WebSourceDiskStorage.seek(file:w ,to: index, size: data.count)
            if #available(iOS 13.4, *) {
                try w.write(contentsOf: data)
            } else {
                w.write(data)
            }
            self.header.dataRanges = WebSourceDiskStorage.mix(range: index...(index + UInt64(data.count) - 1), ranges: self.dataRanges)
            try WebSourceDiskStorage.close(file: w)
            
            pthread_rwlock_unlock(self.rw)
        } catch  {
            try? WebSourceDiskStorage.close(file: w)
            pthread_rwlock_unlock(self.rw)
            throw error
        }
    }
    public func loadHeader() throws {
        guard let r = self.readHandle else { throw NSError(domain: "create read handle error", code: 1, userInfo: nil) }
        do{
            let end = try WebSourceDiskStorage.seekToEnd(file: r)
            if(end > MemoryLayout<UInt64>.size){
                try WebSourceDiskStorage.seek(file: r, to: end - UInt64(MemoryLayout<UInt64>.size), size: 0)
                let data = r.readData(ofLength: MemoryLayout<UInt64>.size)
                let b = UnsafeMutablePointer<UInt8>.allocate(capacity: MemoryLayout<UInt64>.size)
                
                data.copyBytes(to: b, count: MemoryLayout<UInt64>.size)
                
                let u64p = b.withMemoryRebound(to: UInt64.self, capacity: 1) {$0}.pointee
                if(u64p < end - UInt64(MemoryLayout<UInt64>.size)){
                    try WebSourceDiskStorage.seek(file: r, to: end - UInt64(MemoryLayout<UInt64>.size) - u64p , size: Int(u64p))
                    let headerData = r.readData(ofLength: Int(u64p))
                    do {
                        self.header = try JSONDecoder().decode(WebSourceHeaderData.self, from: headerData)
                        
                    } catch {
                        self.header = WebSourceHeaderData(resourceType: "data", dataRanges: [], size: 0, lastRequest: Date(), status: 0)
                    }
                }
            }
        }catch{
            throw error
        }
    }
    public func delete() throws {
        try FileManager.default.removeItem(at: self.url)
    }
    public func close() throws {
        try self.saveHeader()
    }
    public func saveHeader() throws{
        if let headerd = try? JSONEncoder().encode(self.header) ,let write = self.writeHandle{
            do {
                pthread_rwlock_wrlock(self.rw)
                try WebSourceDiskStorage.truncate(file: write, size: self.header.size)
                if #available(iOS 13.4, *) {
                    try write.seekToEnd()
                } else {
                    write.seekToEndOfFile()
                }
                write.write(headerd)
                let len = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
                len.pointee = UInt64(headerd.count)
                let data = Data(bytes: len, count: MemoryLayout<UInt64>.size)
                write.write(data)
                try WebSourceDiskStorage.close(file: write)
                pthread_rwlock_unlock(self.rw)
            } catch {
                pthread_rwlock_unlock(self.rw)
                throw error
            }
        }
    }
    public func loadData() -> Data? {
        guard let r = self.readHandle else { return nil }
        pthread_rwlock_rdlock(self.rw)
        let data = r.readData(ofLength: Int(self.size))
        try? WebSourceDiskStorage.close(file:r)
        pthread_rwlock_unlock(self.rw)
        return data
    }
    //class method
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
            if #available(iOS 13.0, *) {
                try file.truncate(atOffset: to + UInt64(size))
                try file.seek(toOffset: to)
            } else {
                file.truncateFile(atOffset: to + UInt64(size))
                file.seek(toFileOffset: to)
                // Fallback on earlier versions
            }
            
        }else{
            if #available(iOS 13.0, *) {
                try file.seek(toOffset: to)
            } else {
                file.seek(toFileOffset: to)
                // Fallback on earlier versions
                
            }
        }
    }
    public class func truncate(file:FileHandle,size:UInt64) throws{
        if #available(iOS 13.0, *) {
            try file.truncate(atOffset: size)
        } else {
        
        }
    }
    public class func close(file:FileHandle) throws{
        if #available(iOS 13.0, *) {
            try file.close()
        } else {
            file.closeFile()
        }
    }
    public class func seekToEnd(file:FileHandle) throws->UInt64{
        if #available(iOS 13.4, *) {
            return try file.seekToEnd()
        } else {
            return file.seekToEndOfFile()
        }
    }
    public class func readToEndFile(file:FileHandle) throws->Data?{
        if #available(iOS 13.4, *) {
            return try file.readToEnd()
        } else {
            return file.readDataToEndOfFile()
        }
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
    
}
extension ClosedRange where Bound == UInt64{
    public func canMerge(range:ClosedRange<UInt64>)->Bool{
        if(range.overlaps(self)){
            return true
        }else{
            if(range.lowerBound  > self.upperBound && range.lowerBound - self.upperBound == 1){
                return true
            }
            if(self.lowerBound > range.upperBound && self.lowerBound - range.upperBound == 1){
                return true
            }
        }
        return false
    }
    
    public func merge(range:ClosedRange<UInt64>)->ClosedRange<UInt64>{
        return Swift.min(self.lowerBound, range.lowerBound) ... Swift.max(self.upperBound,range.upperBound)
    }
    public func cover(to:ClosedRange<UInt64>)->Bool{
        self.lowerBound <= to.lowerBound && self.upperBound >= to.upperBound
    }
}
extension ClosedRange {
    public func intersect(to:ClosedRange<Bound>)->ClosedRange<Bound>?{
        if(self.overlaps(to)){
            return Swift.max(self.lowerBound, to.lowerBound) ... Swift.min(self.upperBound,to.upperBound)
        }else{
            return nil
        }
        
    }
    public func union(to:ClosedRange<Bound>)->[ClosedRange<Bound>]{
        if(self.overlaps(to)){
            return [Swift.min(self.lowerBound, to.lowerBound) ... Swift.max(self.upperBound,to.upperBound)]
        }else{
            return [self,to].sorted { (left, right) -> Bool in
                left.lowerBound < right.lowerBound
            }
        }
    }
}

extension ClosedRange where Bound == UInt64{
    
    public func except(to:ClosedRange<Bound>)->[ClosedRange<Bound>]{
        if(!self.overlaps(to)){
            return [self]
        }else{
            let low1 = self.lowerBound
            let up1 = to.lowerBound
            var r:[ClosedRange<Bound>] = []
            let low2 = to.upperBound
            let up2 = self.upperBound
            if(low1 < up1 - 1){
                r.append(low1...up1 - 1)
            }
            if(low2 + 1 < up2){
                r.append(low2 + 1...up2)
            }
            return r
        }
    }
    public func except(items:[ClosedRange<Bound>])->[ClosedRange<Bound>]{
        var indexs = [self]
        for i in items {
            let array = indexs
            var result:[ClosedRange<Bound>] = []
            for j in array {
                let r = j.except(to: i)
                result.append(contentsOf: r)
            }
            indexs = result
        }
        return indexs
    }
}
extension ClosedRange where Bound == Int{
    
    public func except(to:ClosedRange<Bound>)->[ClosedRange<Bound>]{
        if(!self.overlaps(to)){
            return [self]
        }else{
            let low1 = self.lowerBound
            let up1 = to.lowerBound
            var r:[ClosedRange<Bound>] = []
            let low2 = to.upperBound
            let up2 = self.upperBound
            if(low1 <= up1 - 1){
                r.append(low1...up1 - 1)
            }
            if(low2 + 1 <= up2){
                r.append(low2 + 1...up2)
            }
            return r
        }
    }
    public func except(items:[ClosedRange<Bound>])->[ClosedRange<Bound>]{
        var indexs = [self]
        for i in items {
            let array = indexs
            var result:[ClosedRange<Bound>] = []
            for j in array {
                let r = j.except(to: i)
                result.append(contentsOf: r)
            }
            indexs = result
        }
        return indexs
    }
}
