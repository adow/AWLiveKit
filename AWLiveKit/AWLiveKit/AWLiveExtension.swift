//
//  AWLiveExtension.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 16/8/9.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

import Foundation
import AVFoundation
import VideoToolbox

extension CMSampleBuffer {
    
    var isKeyFrame: Bool? {
        let attachments = CMSampleBufferGetSampleAttachmentsArray(self, true)
        guard attachments != nil else { return nil }
        
        let unsafePointer = CFArrayGetValueAtIndex(attachments, 0)
        let nsDic = unsafeBitCast(unsafePointer, to: NSDictionary.self)
        guard let dic = nsDic as? Dictionary<String, AnyObject> else { return nil }
        
        guard let dependsOnOthersOptinal = dic["DependsOnOthers"],
            let dependsOnOthers = dependsOnOthersOptinal as? Bool
            else { return nil }
        
        let keyFrame = !dependsOnOthers
        return keyFrame
    }
    
    var dependsOnOthers: Bool {
        guard let
            attachments = CMSampleBufferGetSampleAttachmentsArray(self, false),
            let attachment = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: NSDictionary.self) as? Dictionary<String,AnyObject>
            else { return false }
        
        return attachment["DependsOnOthers"] as! Bool
    }
    
    var dataBuffer: CMBlockBuffer? {
        get {
            return CMSampleBufferGetDataBuffer(self)
        }
        set {
            guard let dataBuffer = newValue else {
                return
            }
            CMSampleBufferSetDataBuffer(self, dataBuffer)
        }
    }
    
    var duration: CMTime {
        return CMSampleBufferGetDuration(self)
    }
    
    var formatDescription: CMFormatDescription? {
        return CMSampleBufferGetFormatDescription(self)
    }
    var isDataReady : Bool {
        return CMSampleBufferDataIsReady(self)
    }
    
    var decodeTimeStamp: CMTime {
        let decodeTimestamp = CMSampleBufferGetDecodeTimeStamp(self)
        return decodeTimestamp == kCMTimeInvalid ? presentationTimeStamp : decodeTimestamp
    }
    
    var presentationTimeStamp: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }
    var sps_data : Data? {
        return self.get_sps_or_pps_data(0, sampleBuffer: self)
    }
    var pps_data : Data? {
        return self.get_sps_or_pps_data(1, sampleBuffer: self)
    }
    
    func get_sps_or_pps_data(_ choice : Int ,sampleBuffer:CMSampleBuffer) -> Data?{
        let format = CMSampleBufferGetFormatDescription(sampleBuffer)
        guard format != nil else { return nil }
        
        var paramSet = UInt8()
        var paramSetPtr = withUnsafePointer(to: &paramSet, {
            (ptr) -> UnsafePointer<UInt8>? in
            return ptr
        })
        
        var paraSetSize = Int()
        var paraSetCount = Int()
        var naluHeadLen = Int32()
        let paraSetIndex = choice
        
        
        let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format!,
                                                                        paraSetIndex,
                                                                        &paramSetPtr,
                                                                        &paraSetSize,
                                                                        &paraSetCount,
                                                                        &naluHeadLen)
        if status == noErr {
            // choice: true means sps. false means pps
            let paraData = Data(bytes: UnsafePointer<UInt8>(paramSetPtr!), count: paraSetSize)
            return paraData
        } else {
            print("CMVideoFormatDescriptionGetH264ParameterSetAtIndex error:\(status)")
            return nil
        }
    }
}
extension ExpressibleByIntegerLiteral {
//    var bytes: [UInt8] {
//        var value: Self = self
//        return withUnsafePointer(to: &value) {
//            (p) in
//        
//            Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(p), count: MemoryLayout<Self>.size))
//            
//            let p_2 = UnsafeBufferPointer(start: p, count: MemoryLayout<Self>.size)
//        }
//    }
//    
//    init(bytes: [UInt8]) {
//        self = bytes.withUnsafeBufferPointer {
//            return UnsafeRawPointer($0.baseAddress!).load(as: Self.self)
//        }
//    }
}
extension String {
    
    var pointer: UnsafePointer<Int8> {
        return withCString { (ptr) -> UnsafePointer<Int8> in
            return ptr
        }
    }
    
    var mutablePointer: UnsafeMutablePointer<Int8> {
        return withCString({ (ptr) -> UnsafeMutablePointer<Int8> in
            return UnsafeMutablePointer(mutating: ptr)
        })
    }
    
    var asciiString: UnsafePointer<Int8> {
        return (self as NSString).cString(using: String.Encoding.ascii.rawValue)!
    }
    
    
}
