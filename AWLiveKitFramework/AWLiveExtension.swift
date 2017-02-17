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
    
    public var isKeyFrame: Bool? {
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
    
    public var dependsOnOthers: Bool {
        guard let
            attachments = CMSampleBufferGetSampleAttachmentsArray(self, false),
            let attachment = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: NSDictionary.self) as? Dictionary<String,AnyObject>
            else { return false }
        
        return attachment["DependsOnOthers"] as! Bool
    }
    
    public var dataBuffer: CMBlockBuffer? {
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
    
    public var duration: CMTime {
        return CMSampleBufferGetDuration(self)
    }
    
    public var formatDescription: CMFormatDescription? {
        return CMSampleBufferGetFormatDescription(self)
    }
    public var isDataReady : Bool {
        return CMSampleBufferDataIsReady(self)
    }
    
    public var decodeTimeStamp: CMTime {
        let decodeTimestamp = CMSampleBufferGetDecodeTimeStamp(self)
        return decodeTimestamp == kCMTimeInvalid ? presentationTimeStamp : decodeTimestamp
    }
    
    public var presentationTimeStamp: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }
    public var sps_data : Data? {
        return self.get_sps_or_pps_data(0, sampleBuffer: self)
    }
    public var pps_data : Data? {
        return self.get_sps_or_pps_data(1, sampleBuffer: self)
    }
    
    public func get_sps_or_pps_data(_ choice : Int ,sampleBuffer:CMSampleBuffer) -> Data?{
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
    
    public var pointer: UnsafePointer<Int8> {
        return withCString { (ptr) -> UnsafePointer<Int8> in
            return ptr
        }
    }
    
    public var mutablePointer: UnsafeMutablePointer<Int8> {
        return withCString({ (ptr) -> UnsafeMutablePointer<Int8> in
            return UnsafeMutablePointer(mutating: ptr)
        })
    }
    
    public var asciiString: UnsafePointer<Int8> {
        return (self as NSString).cString(using: String.Encoding.ascii.rawValue)!
    }
    
    
}
extension AVCaptureDevice {
    public func testSessionPreset() {
        var session_preset_list : [String:String] = [ "AVCaptureSessionPresetPhoto":AVCaptureSessionPresetPhoto,
                                                      "AVCaptureSessionPresetHigh": AVCaptureSessionPresetHigh,
                                                      "AVCaptureSessionPresetMedium":AVCaptureSessionPresetMedium,
                                                      "AVCaptureSessionPresetLow":AVCaptureSessionPresetLow,
                                                      "AVCaptureSessionPreset352x288":AVCaptureSessionPreset352x288,
                                                      "AVCaptureSessionPreset640x480":AVCaptureSessionPreset640x480,
                                                      "AVCaptureSessionPreset1280x720":AVCaptureSessionPreset1280x720,
                                                      "AVCaptureSessionPreset1920x1080":AVCaptureSessionPreset1920x1080,
                                                      "AVCaptureSessionPresetiFrame960x540":AVCaptureSessionPresetiFrame960x540,
                                                      "AVCaptureSessionPresetiFrame1280x720":AVCaptureSessionPresetiFrame1280x720,
                                                      "AVCaptureSessionPresetInputPriority":AVCaptureSessionPresetInputPriority,
                                                      
                                                      ]
        if #available(iOS 9.0, *) {
            session_preset_list["AVCaptureSessionPreset3840x2160"] = AVCaptureSessionPreset3840x2160
        } else {
            // Fallback on earlier versions
        }
        session_preset_list.forEach { (k,v) in
            let result = self.supportsAVCaptureSessionPreset(v)
            debugPrint("\(k):\(result)")
        }
    }
}
