//
//  AWEncoder.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 16/8/9.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

import UIKit
import AVFoundation
import VideoToolbox


// MARK: - VideoEncoder
typealias AWVideoEncoderCallback = (CMSampleBuffer) -> ()

enum AWVideoEncoderBitrate : Int {
    case _450kbs = 0, _500kbs,_600kbs, _800kbs, _1000kbs, _1200kbs, _1500kbs, _2000kbs, _2500kbs, _3000kbs, _4000kbs
    var bitrates : Int {
        switch self {
        case ._450kbs:
            return 450 * 1024
        case ._500kbs:
            return 500 * 1024
        case ._600kbs:
            return 600 * 1024
        case ._800kbs:
            return 800 * 1024
        case ._1000kbs:
            return 1000 * 1024
        case ._1200kbs:
            return 1200 * 1024
        case ._1500kbs:
            return 1500 * 1024
        case ._2000kbs:
            return 2000 * 1024
        case ._2500kbs:
            return 2500 * 1024
        case ._3000kbs:
            return 3000 * 1024
        case ._4000kbs:
            return 4000 * 1024
        }
    }
}
enum AWVideoEncoderFPS : Int {
    case _20 = 20, _25 = 25, _30 = 30, _60 = 60
    var fps : Int {
        switch self {
        case ._20:
            return 20
        case ._25:
            return 25
        case ._30:
            return 30
        case ._60:
            return 60
        }
    }
}
enum AWVideoEncoderProfile : Int {
    case Baseline = 0, Main, High
    var profile : CFString {
        switch self {
        case .Baseline:
            return kVTProfileLevel_H264_Baseline_AutoLevel
        case .Main:
            return kVTProfileLevel_H264_Main_AutoLevel
        case .High:
            return kVTProfileLevel_H264_High_AutoLevel
        }
    }
}

class AWVideoEncoder: NSObject {
    private var videoCompressionSession : VTCompressionSession? = nil
    var attributes : [NSString:AnyObject]!
    var onEncoded : AWVideoEncoderCallback? = nil
    init(outputSize:CGSize, bitrate : AWVideoEncoderBitrate = ._600kbs, fps : AWVideoEncoderFPS = ._30) {
        super.init()
        NSLog("Encoder OutputSize:\(outputSize)")
        NSLog("Encoder bitrate:\(bitrate.bitrates)")
        NSLog("Encoder fps:\(fps.fps)")
        var profile = AWVideoEncoderProfile.Main
        if bitrate.bitrates >= 800 * 1024 {
            profile = .High
            NSLog("Encoder profile High")
        }
        else if bitrate.bitrates >= 500 * 1024 {
            profile = .Main
            NSLog("Encoder profile: Main")
        }
        else {
            profile = .Baseline
            NSLog("Encoder profile: Baseline")
        }
        attributes = [
                kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferIOSurfacePropertiesKey: [:],
                kCVPixelBufferOpenGLESCompatibilityKey: true,
                kCVPixelBufferWidthKey:NSNumber(int: Int32(outputSize.width)),
                kCVPixelBufferHeightKey:NSNumber(int: Int32(outputSize.height)),
            ]
        /// create session
        let status = VTCompressionSessionCreate(kCFAllocatorDefault,
                                                Int32(outputSize.width), Int32(outputSize.height),
                                                kCMVideoCodecType_H264,
                                                nil,
                                                attributes,
                                                nil,
                                                encodeCallback,
                                                unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                                                &(self.videoCompressionSession))
        if status != noErr {
            NSLog("Create Compression Session Error:\(status)")
            return
        }
        VTSessionSetProperty(self.videoCompressionSession!,
                             kVTCompressionPropertyKey_RealTime,
                             kCFBooleanTrue)
        VTSessionSetProperty(self.videoCompressionSession!,
                             kVTCompressionPropertyKey_AllowFrameReordering,
                             kCFBooleanFalse)
        VTSessionSetProperty(self.videoCompressionSession!,
                             kVTCompressionPropertyKey_ProfileLevel,
                             profile.profile)
        VTSessionSetProperty(self.videoCompressionSession!,
                             kVTCompressionPropertyKey_AllowTemporalCompression,
                             kCFBooleanTrue)
        if VTSessionSetProperty(self.videoCompressionSession!,
                                kVTCompressionPropertyKey_AverageBitRate,
                                NSNumber(integer: bitrate.bitrates)) != noErr {
            print("Set BitRate Failed")
        }
        VTSessionSetProperty(self.videoCompressionSession!,
                             kVTCompressionPropertyKey_MaxKeyFrameInterval,
                             NSNumber(integer: fps.fps))
        /// Encode
        if VTCompressionSessionPrepareToEncodeFrames(self.videoCompressionSession!) != noErr {
            NSLog("Prepare to Encode Frames Error")
        }
    
    }
    func close() {
        guard let _videoCompressionSession = self.videoCompressionSession else {
            return
        }
        VTCompressionSessionCompleteFrames(_videoCompressionSession, kCMTimeInvalid)
        /// release session
        VTCompressionSessionInvalidate(_videoCompressionSession)
        self.videoCompressionSession = nil
    }
    /// 编码
    func encodeSampleBuffer(sampleBuffer:CMSampleBuffer){
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        guard let _pixelBuffer = pixelBuffer else {
            NSLog("No Pixel Buffer")
            return
        }
        let presentationTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetOutputDuration(sampleBuffer)
        self.encodePixelBuffer(_pixelBuffer, presentationTime: presentationTime, duration: duration)
        
    }
    /// 编码
    func encodePixelBuffer(pixelBuffer:CVPixelBuffer, presentationTime: CMTime, duration : CMTime) {
        guard let _compressionSeession = self.videoCompressionSession else {
            NSLog("No VideoCompressionSession")
            return
        }
        
        /// Lock
        if CVPixelBufferLockBaseAddress(pixelBuffer, 0) != kCVReturnSuccess {
            NSLog("Lock Pixel Buffer Base Address Error")
        }
        
        //            print("Sample Time:\(presentationTime),\(duration)")
        //            let t_start = NSDate()
        if VTCompressionSessionEncodeFrame(_compressionSeession,
                                           pixelBuffer,
                                           presentationTime, duration,
                                           nil, nil, nil) != noErr {
            NSLog("Encode Frame Error")
        }
        /// Unlock
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0)
    }
    /// 编码回调
    var encodeCallback : VTCompressionOutputCallback = {
        (outputCallbackRefCon: UnsafeMutablePointer<Void>,
        sourceFrameRefCon: UnsafeMutablePointer<Void>,
        status: OSStatus,
        infoFlags: VTEncodeInfoFlags,
        sampleBuffer: CMSampleBuffer?) in
        guard let _buffer = sampleBuffer else {
            return
        }
        let _self = unsafeBitCast(outputCallbackRefCon, AWVideoEncoder.self)
        _self.onEncoded?(_buffer)
        
    }
}
