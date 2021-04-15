//
//  WebSourceDownloader.swift
//  test
//
//  Created by hao yin on 2021/4/14.
//

import Foundation

public struct HTTPError:Error{
    public var statueCode:Int
}
public protocol WebSourceDownloaderDelegate:class{
    func handleData(downloader:WebSourceDownloader,data:Data?,range:ClosedRange<UInt64>?,error:Error?)
    func handleMetaData(downloader:WebSourceDownloader,error:Error?)
    func handleComplete(downloader:WebSourceDownloader,islocal:Bool)
}

public class WebSourceDownloader{
    
    
    public weak var delegate:WebSourceDownloaderDelegate?
    public var storage:WebSourceStorage
    public var group = DispatchGroup()
    public let url:URL
    public let maxPage:UInt64 = 4 * 1024
    public var mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    public convenience init(url:URL) throws {
        let u = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("WebSourceDownloader")
        
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true, attributes: nil)
        guard let digest = WebSourceDiskStorage.digest(name: url.absoluteString) else { throw NSError(domain: "url fail", code: 0, userInfo: nil) }
        let storage = try WebSourceDiskStorage(dir: u, identify: digest)
        self.init(storage:storage,url:url)
    }
    public required init(storage:WebSourceStorage,url:URL){
        self.storage = storage
        self.url = url
        
        self.storage.dataHeader.status = 0
        print(self.storage)
        pthread_mutex_init(self.mutex, nil)
    }
    
   
    public func download(partialRange:ClosedRange<UInt64>? = nil,next:Bool = false){
        DispatchQueue.global().async {
            var u = URLRequest(url: self.url)
            var waitingRange:ClosedRange<UInt64> = 0...0
            let currentRange = partialRange ?? 0...(self.maxPage - 1)
            u = self.loadRange(req: u, range: currentRange, waiting: &waitingRange)
            if(self.storage.complete(range: currentRange)){
                if(waitingRange.lowerBound == waitingRange.upperBound){
                    if(self.storage.isComplete){
                        self.delegate?.handleComplete(downloader: self, islocal: true)
                    }
                    return
                }
                print(currentRange,"success")
                self.download(partialRange: waitingRange)
                return
            }
            pthread_mutex_lock(self.mutex)
            self.request(request: u) { (data, response, e) in
                if(e == nil){
                    guard let rep = response else { pthread_mutex_unlock(self.mutex);return }
                    do {
                        try self.saveData(rep: rep, data: data,waiting: &waitingRange)
                        pthread_mutex_unlock(self.mutex)
                        if(waitingRange.upperBound > waitingRange.lowerBound){
                            self.download(partialRange: waitingRange,next: true)
                        }
                    } catch {
                        print(error)
                        pthread_mutex_unlock(self.mutex)
                        if(waitingRange.upperBound > waitingRange.lowerBound && next){
                            self.download(partialRange: waitingRange,next: false)
                        }
                    }
                }
                self.delegate?.handleData(downloader: self, data: data, range: waitingRange, error: e)
                if(self.storage.isComplete){
                    self.delegate?.handleComplete(downloader: self,islocal: false)
                }
            }
        }
    }
    
    public func request(request:URLRequest,callback:@escaping (Data?,HTTPURLResponse?,Error?)->Void){
        let req = WebSourceCookie.shared.loadCookie(request: request)
        #if DEBUG
        print(request.url as Any ,request.allHTTPHeaderFields as Any)
        #endif
        WebSourceDownloader.session.dataTask(with: req) { (d, r, e) in
            if let error = e{
                callback(d,nil,error)
                return
            }else{
                guard let httpr = r as? HTTPURLResponse else { callback(d,nil,e);return }
                WebSourceCookie.shared.saveCookie(response: httpr)
                if(httpr.statusCode >= 200 && httpr.statusCode < 300){
                    callback(d,httpr,nil)
                }else if(httpr.statusCode >= 300 && httpr.statusCode < 400){
                    callback(d,httpr,nil)
                }else if(httpr.statusCode >= 400 && httpr.statusCode < 600){
                    callback(d,httpr,HTTPError(statueCode: httpr.statusCode))
                }else{
                    callback(d,httpr,HTTPError(statueCode: httpr.statusCode))
                }
            }
            #if DEBUG
            print(r as Any)
            #endif
        }.resume()
    }
    deinit {
        pthread_mutex_destroy(self.mutex)
        self.mutex.deallocate()
    }
    
    public static var session:URLSession = {
        let queue = OperationQueue()
        queue.name = "WebSourceDownloader"
        return URLSession(configuration: .default, delegate: nil, delegateQueue: queue)
    }()
    
    private func prepare(){
        if(self.storage.dataHeader.status > 0){
            return
        }
        pthread_mutex_lock(self.mutex)
        var u = URLRequest(url: self.url)
        u.httpMethod = "head"
        u = self.loadMetaData(rep: u)
        self.request(request: u) { (data, response, e) in
            if(e == nil){
                guard let rep = response else { pthread_mutex_unlock(self.mutex);return }
                var range:ClosedRange<UInt64> = 0...0
                try? self.saveData(rep: rep,data:data, waiting: &range)
            }
            pthread_mutex_unlock(self.mutex)
            self.delegate?.handleMetaData(downloader: self, error: e)
        }
    }
    private func saveData(rep:HTTPURLResponse,data:Data?,waiting:inout ClosedRange<UInt64>) throws {
        
        
        if let range = self.getRange(rep: rep){
            self.storage.size = range.1
            if let dat = data{
                try self.storage.saveData(data: dat, index: range.0.lowerBound)
            }
            waiting = range.0
            
        }else{
            self.storage.size = UInt64(rep.allHeaderFields["Content-Length"] as? String ?? "null") ?? UInt64(data?.count ?? 0)

            if let d = data{
                try self.storage.saveData(data: d, index: 0)
            }
        }
        self.storage.resourceType = rep.allHeaderFields["Content-Type"] as? String ?? "Data"
        self.storage.dataHeader.etag = rep.allHeaderFields["Etag"] as? String
        self.storage.dataHeader.lastRequestDate = rep.allHeaderFields["Last-Modified"] as? String
        self.storage.dataHeader.status = rep.statusCode
        self.storage.dataHeader.expiresDate = rep.allHeaderFields["Expires"] as? String
        try? self.storage.close()
    }
    private func getRange(rep:HTTPURLResponse)->(ClosedRange<UInt64>,UInt64)?{
        if let info = rep.allHeaderFields["Content-Range"] as? String {
            let rangeInfo = info.components(separatedBy: "/")
            guard let size = rangeInfo.last,let sizen = UInt64(size) else { return nil }
            guard let rage =  rangeInfo.first?.components(separatedBy: .whitespaces).last else { return nil }
            guard let s = rage.components(separatedBy: "-").first ,let start = UInt64(s) else { return nil}
            guard let e = rage.components(separatedBy: "-").last ,let end = UInt64(e) else { return nil }
            return (start...end,sizen)
        }
        return nil
    }
    private func loadMetaData(rep:URLRequest)->URLRequest{
        var u = rep
        u.setValue(self.storage.dataHeader.etag, forHTTPHeaderField: "If-None-Match")
        u.setValue(self.storage.dataHeader.lastRequestDate, forHTTPHeaderField: "If-Modified-Since")
//        u.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        return u
    }
    private func loadRange(req:URLRequest,range:ClosedRange<UInt64>, waiting:inout ClosedRange<UInt64>)->URLRequest{
        var currentRange:ClosedRange<UInt64>
        var request = req
        if(range.upperBound - range.lowerBound + 1 > self.maxPage){
            currentRange = range.lowerBound ... range.lowerBound + maxPage - 1
            waiting = range.lowerBound + maxPage ... range.upperBound
        }else{
            currentRange = range
            waiting = 0...0
        }
        if(self.storage.size != 0){
            if(self.storage.size <= currentRange.upperBound && currentRange.lowerBound < self.storage.size - 1){
                currentRange = range.lowerBound ... (self.storage.size - 1)
                waiting = 0...0
            }else if self.storage.size > currentRange.upperBound && currentRange.lowerBound < self.storage.size - 1{
                if(currentRange.upperBound >= self.storage.size - 1){
                    waiting = 0...0
                }else{
                    waiting = currentRange.upperBound + 1 ... (self.storage.size - 1)
                }
            }else{
                waiting = 0...0
            }
        }
        request.setValue("bytes=\(currentRange.lowerBound)-\(currentRange.upperBound)", forHTTPHeaderField: "Range")
        return request
    }
}
