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
public typealias AWVideoEncoderCallback = (CMSampleBuffer) -> ()

// MARK: Bitrate
public enum AWVideoEncoderBitrate : Int, CustomStringConvertible {
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
    /// 相关的 fps
    public var recommandedFPS : AWVideoEncoderFPS {
        switch self {
        case ._450kbs:
            return AWVideoEncoderFPS._20
        case ._500kbs:
            return AWVideoEncoderFPS._25
        default:
            return AWVideoEncoderFPS._30
        }
    }
    /// 相关的 profile
    public var recommandedProfile : AWVideoEncoderProfile {
        switch self {
        case ._450kbs, ._500kbs:
            return AWVideoEncoderProfile.baseline
        case ._600kbs, ._800kbs, ._1000kbs:
            return AWVideoEncoderProfile.main
        case ._1200kbs, ._1500kbs, ._2000kbs, ._2500kbs, ._3000kbs, ._4000kbs:
            return AWVideoEncoderProfile.high
        }
    }
    public var description: String {
        switch self {
        case ._450kbs:
            return "450kbs"
        case ._500kbs:
            return "500kbs"
        case ._600kbs:
            return "600kbs"
        case ._800kbs:
            return "800kbs"
        case ._1000kbs:
            return "1000kbs"
        case ._1200kbs:
            return "1200kbs"
        case ._1500kbs:
            return "1500kbs"
        case ._2000kbs:
            return "2000kbs"
        case ._2500kbs:
            return "2500kbs"
        case ._3000kbs:
            return "3000kbs"
        case ._4000kbs:
            return "4000kbs"
        }
    }
}
// MARK: fps
public enum AWVideoEncoderFPS : Int , CustomStringConvertible{
    case _20 = 20, _25 = 25, _30 = 30, _60 = 60
    public var fps : Int {
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
    public var description: String {
        return String(self.rawValue)
    }
}
// MARK: profile
public enum AWVideoEncoderProfile : Int , CustomStringConvertible{
    case baseline = 0, main, high
    public var profile : CFString {
        switch self {
        case .baseline:
            return kVTProfileLevel_H264_Baseline_AutoLevel
        case .main:
            return kVTProfileLevel_H264_Main_AutoLevel
        case .high:
            return kVTProfileLevel_H264_High_AutoLevel
        }
    }
    public var description: String {
        switch self {
        case .baseline:
            return "kVTProfileLevel_H264_Baseline_AutoLevel"
        case .main:
            return "kVTProfileLevel_H264_Main_AutoLevel"
        case .high:
            return "kVTProfileLevel_H264_High_AutoLevel"
        }
    }
}

// MARK: Video Encoder
public class AWVideoEncoder: NSObject {
    fileprivate var videoCompressionSession : VTCompressionSession? = nil
    public var attributes : [NSString:AnyObject]!
    public var onEncoded : AWVideoEncoderCallback? = nil
    public init(outputSize:CGSize,
         bitrate : AWVideoEncoderBitrate = ._600kbs,
         fps : AWVideoEncoderFPS = ._30,
         profile : AWVideoEncoderProfile = .main) {
        super.init()
        NSLog("Video Encoder OutputSize:\(outputSize)")
        NSLog("Video Encoder bitrate:\(bitrate)")
        NSLog("Video Encoder fps:\(fps)")
        NSLog("Video Encoder Profile:\(profile)")

        attributes = [
                kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA) as AnyObject,
                kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
                kCVPixelBufferOpenGLESCompatibilityKey: true as AnyObject,
                kCVPixelBufferWidthKey:NSNumber(value: Int32(outputSize.width) as Int32),
                kCVPixelBufferHeightKey:NSNumber(value: Int32(outputSize.height) as Int32),
            ]
        /// create session
        let status = VTCompressionSessionCreate(kCFAllocatorDefault,
                                                Int32(outputSize.width), Int32(outputSize.height),
                                                kCMVideoCodecType_H264,
                                                nil,
                                                attributes as CFDictionary?,
                                                nil,
                                                encodeCallback,
                                                unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
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
                                NSNumber(value: bitrate.bitrates as Int)) != noErr {
            print("Set BitRate Failed")
        }
        VTSessionSetProperty(self.videoCompressionSession!,
                             kVTCompressionPropertyKey_MaxKeyFrameInterval,
                             NSNumber(value: fps.fps as Int))
        /// Encode
        if VTCompressionSessionPrepareToEncodeFrames(self.videoCompressionSession!) != noErr {
            NSLog("Prepare to Encode Frames Error")
        }
    
    }
    public func close() {
        guard let _videoCompressionSession = self.videoCompressionSession else {
            return
        }
        VTCompressionSessionCompleteFrames(_videoCompressionSession, kCMTimeInvalid)
        /// release session
        VTCompressionSessionInvalidate(_videoCompressionSession)
        self.videoCompressionSession = nil
    }
    /// 编码
    public func encodeSampleBuffer(_ sampleBuffer:CMSampleBuffer){
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
    public func encodePixelBuffer(_ pixelBuffer:CVPixelBuffer, presentationTime: CMTime, duration : CMTime) {
        guard let _compressionSeession = self.videoCompressionSession else {
            NSLog("No VideoCompressionSession")
            return
        }
        
        /// Lock
        if CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0))) != kCVReturnSuccess {
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
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
    }
    /// 编码回调
    public var encodeCallback : VTCompressionOutputCallback = {
        (outputCallbackRefCon: UnsafeMutableRawPointer?,
        sourceFrameRefCon: UnsafeMutableRawPointer?,
        status: OSStatus,
        infoFlags: VTEncodeInfoFlags,
        sampleBuffer: CMSampleBuffer?) in
        guard let _buffer = sampleBuffer else {
            return
        }
        let _self = unsafeBitCast(outputCallbackRefCon!, to: AWVideoEncoder.self)
        _self.onEncoded?(_buffer)
        
    }
}
// MARK: Audio Encoder
private var g_audioInputFormat : AudioStreamBasicDescription!
public typealias AWAudioEncoderCallback = (AudioBufferList) -> ()
public class AWAudioEncoder {
    public var audioConverter : AudioConverterRef? = nil
    public var onEncoded : AWAudioEncoderCallback? = nil
    public init() {
        
    }
    /// 初始化编码器，因为要知道 audioInputFormat, 所以必须从第一个 sampleBuffer 获取格式后创建
    fileprivate func setup() {
        guard self.audioConverter == nil else {
            return
        }
        
        var outputFormat : AudioStreamBasicDescription = AudioStreamBasicDescription()
        outputFormat.mSampleRate = g_audioInputFormat.mSampleRate
        outputFormat.mFormatID = kAudioFormatMPEG4AAC
        outputFormat.mChannelsPerFrame = g_audioInputFormat.mChannelsPerFrame
        outputFormat.mFramesPerPacket = 1024
        outputFormat.mFormatFlags = UInt32(MPEG4ObjectID.aac_Main.rawValue)
        
        var audioClassDescription_list = [
            AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleHardwareAudioCodecManufacturer),
            AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleSoftwareAudioCodecManufacturer),
            ]
        guard AudioConverterNewSpecific(
            &g_audioInputFormat!,
            &outputFormat,
            UInt32(audioClassDescription_list.count),
            &audioClassDescription_list,
            &audioConverter)  == noErr else {
                                            NSLog("AudioConverterNewSpecific Failed")
                                            return
        }
        NSLog("AudioEncoder Setup")
    }
    public func encodeSampleBuffer(_ sampleBuffer:CMSampleBuffer) {
        let format = CMSampleBufferGetFormatDescription(sampleBuffer)
        let sourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(format!)?.pointee
        g_audioInputFormat = sourceFormat
        
        self.setup()
        
        guard self.audioConverter != nil else {
            NSLog("Audio Converter nil")
            return
        }
        
        var blockBuffer : CMBlockBuffer? = nil
        var inBufferList = AudioBufferList()
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
                  nil,
                  &inBufferList,
                  MemoryLayout<AudioBufferList>.size,
                  nil,
                  nil,
                  0,
                  &blockBuffer) == noErr else {
                    NSLog("CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer Failed")
                    return
        }
        
        let frameSize : UInt32 = 1024
        let dataPtr = UnsafeMutableRawPointer.allocate(bytes: Int(frameSize),
                                                       alignedTo: MemoryLayout<Int>.alignment)
        let channels = g_audioInputFormat.mChannelsPerFrame
        let  audioBuffer = AudioBuffer(mNumberChannels: channels,
                                       mDataByteSize: frameSize,
                                       mData: dataPtr)
//        dataPtr.deinitialize()
        var outBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
        var outputDataPacketSize : UInt32 = 1
        var outputPacketDescription = AudioStreamPacketDescription()
        let status =  AudioConverterFillComplexBuffer(audioConverter!,
            self.encoderCallback,
            &inBufferList,
            &outputDataPacketSize,
            &outBufferList,
            &outputPacketDescription)
        guard status == noErr else {
            NSLog("AudioConverterFillComplexBuffer Failed:\(status)")
            return
        }
        
        self.onEncoded?(outBufferList)
    }
    public var encoderCallback : AudioConverterComplexInputDataProc = {
        (setupAudioEncoderFromSampleBufferinAudioConverter: AudioConverterRef,
        ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
        ioData: UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
        inUserData: UnsafeMutableRawPointer?) in
        guard let inBufferList = unsafeBitCast(inUserData, to: (UnsafeMutablePointer<AudioBufferList>?.self)) else {
            ioNumberDataPackets.pointee = 0
            NSLog("ioNumberDataPackets empty")
            return 1024
        }
        
        let numBytes : UInt32 =
            min(ioNumberDataPackets.pointee * g_audioInputFormat.mBytesPerPacket,
                inBufferList.pointee.mBuffers.mDataByteSize)
        
        ioData.pointee.mBuffers.mData = inBufferList.pointee.mBuffers.mData
        ioData.pointee.mBuffers.mDataByteSize = numBytes
        ioNumberDataPackets.pointee = numBytes / g_audioInputFormat.mBytesPerPacket
        return noErr
    }

}
