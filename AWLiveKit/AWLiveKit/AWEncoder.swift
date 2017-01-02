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

// MARK: Bitrate
enum AWVideoEncoderBitrate : Int, CustomStringConvertible {
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
    var recommandedFPS : AWVideoEncoderFPS {
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
    var recommandedProfile : AWVideoEncoderProfile {
        switch self {
        case ._450kbs, ._500kbs:
            return AWVideoEncoderProfile.Baseline
        case ._600kbs, ._800kbs, ._1000kbs:
            return AWVideoEncoderProfile.Main
        case ._1200kbs, ._1500kbs, ._2000kbs, ._2500kbs, ._3000kbs, ._4000kbs:
            return AWVideoEncoderProfile.High
        }
    }
    var description: String {
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
enum AWVideoEncoderFPS : Int , CustomStringConvertible{
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
    var description: String {
        return String(self.rawValue)
    }
}
// MARK: profile
enum AWVideoEncoderProfile : Int , CustomStringConvertible{
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
    var description: String {
        switch self {
        case .Baseline:
            return "kVTProfileLevel_H264_Baseline_AutoLevel"
        case .Main:
            return "kVTProfileLevel_H264_Main_AutoLevel"
        case .High:
            return "kVTProfileLevel_H264_High_AutoLevel"
        }
    }
}

// MARK: Video Encoder
class AWVideoEncoder: NSObject {
    private var videoCompressionSession : VTCompressionSession? = nil
    var attributes : [NSString:AnyObject]!
    var onEncoded : AWVideoEncoderCallback? = nil
    init(outputSize:CGSize,
         bitrate : AWVideoEncoderBitrate = ._600kbs,
         fps : AWVideoEncoderFPS = ._30,
         profile : AWVideoEncoderProfile = .Main) {
        super.init()
        NSLog("Video Encoder OutputSize:\(outputSize)")
        NSLog("Video Encoder bitrate:\(bitrate)")
        NSLog("Video Encoder fps:\(fps)")
        NSLog("Video Encoder Profile:\(profile)")

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
// MARK: Audio Encoder
private var g_audioInputFormat : AudioStreamBasicDescription!
typealias AWAudioEncoderCallback = (AudioBufferList) -> ()
class AWAudioEncoder {
    var audioConverter : AudioConverterRef = nil
    var onEncoded : AWAudioEncoderCallback? = nil
    init() {
        
    }
    /// 初始化编码器，因为要知道 audioInputFormat, 所以必须从第一个 sampleBuffer 获取格式后创建
    private func setup() {
        guard self.audioConverter == nil else {
            return
        }
        
        var outputFormat : AudioStreamBasicDescription = AudioStreamBasicDescription()
        outputFormat.mSampleRate = g_audioInputFormat.mSampleRate
        outputFormat.mFormatID = kAudioFormatMPEG4AAC
        outputFormat.mChannelsPerFrame = g_audioInputFormat.mChannelsPerFrame
        outputFormat.mFramesPerPacket = 1024
        outputFormat.mFormatFlags = UInt32(MPEG4ObjectID.AAC_Main.rawValue)
        
        var audioClassDescription_list = [
            AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleHardwareAudioCodecManufacturer),
            AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleSoftwareAudioCodecManufacturer),
            ]
        guard AudioConverterNewSpecific(&g_audioInputFormat!,
                                        &outputFormat,
                                        UInt32(audioClassDescription_list.count),
                                        &audioClassDescription_list,
                                        &audioConverter)  == noErr else {
                                            NSLog("AudioConverterNewSpecific Failed")
                                            return
        }
        NSLog("AudioEncoder Setup")
    }
    func encodeSampleBuffer(sampleBuffer:CMSampleBuffer) {
        let format = CMSampleBufferGetFormatDescription(sampleBuffer)
        let sourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(format!).memory
        g_audioInputFormat = sourceFormat
//        g_audioInputFormat.mFormatID = kAudioFormatLinearPCM
//        g_audioInputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked
//        g_audioInputFormat.mFramesPerPacket = 1
//        g_audioInputFormat.mBitsPerChannel = 16;
//        g_audioInputFormat.mBytesPerFrame = g_audioInputFormat.mBitsPerChannel / 8 * g_audioInputFormat.mChannelsPerFrame;
//        g_audioInputFormat.mBytesPerPacket = g_audioInputFormat.mBytesPerFrame * g_audioInputFormat.mFramesPerPacket;
        
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
                  sizeof(AudioBufferList.self),
                  nil,
                  nil,
                  0,
                  &blockBuffer) == noErr else {
                    NSLog("CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer Failed")
                    return
        }
        
        let frameSize : UInt32 = 1024
        let dataPtr = UnsafeMutablePointer<Void>.alloc(Int(frameSize))
        let channels = g_audioInputFormat.mChannelsPerFrame
        let  audioBuffer = AudioBuffer(mNumberChannels: channels,
                                       mDataByteSize: frameSize,
                                       mData: dataPtr)
        dataPtr.destroy()
        var outBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
        var outputDataPacketSize : UInt32 = 1
        var outputPacketDescription = AudioStreamPacketDescription()
        let status =  AudioConverterFillComplexBuffer(audioConverter,
                                                      self.encoderCallback,
                                                      &inBufferList,
                                                      &outputDataPacketSize,
                                                      &outBufferList,
                                                      &outputPacketDescription)
        guard status == noErr else {
            NSLog("AudioConverterFillComplexBuffer Failed:\(status)")
            return
        }
        
//        let audio_data_length = outBufferList.mBuffers.mDataByteSize
//        let audio_data_bytes = outBufferList.mBuffers.mData
//        let timeStamp = abs(self.startTime.timeIntervalSinceNow) * 1000
        //        let audio_data = NSData(bytes: audio_data_bytes, length: Int(audio_data_length))
        //        print("\(audio_data_length), \(timeStamp):\(audio_data)")
//        aw_rtmp_send_audio(UnsafeMutablePointer<UInt8>(audio_data_bytes), audio_data_length, UInt32(timeStamp))
        self.onEncoded?(outBufferList)
    }
    var encoderCallback : AudioConverterComplexInputDataProc = {
        (setupAudioEncoderFromSampleBufferinAudioConverter: AudioConverterRef,
        ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
        ioData: UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>>,
        inUserData: UnsafeMutablePointer<Void>) in
        let inBufferList = unsafeBitCast(inUserData, UnsafeMutablePointer<AudioBufferList>.self)
        guard inBufferList != nil else {
            ioNumberDataPackets.memory = 0
            NSLog("ioNumberDataPackets empty")
            return 1024
        }
        
        let numBytes : UInt32 =
            min(ioNumberDataPackets.memory * g_audioInputFormat.mBytesPerPacket,
                inBufferList.memory.mBuffers.mDataByteSize)
        
        ioData.memory.mBuffers.mData = inBufferList.memory.mBuffers.mData
        ioData.memory.mBuffers.mDataByteSize = numBytes
        ioNumberDataPackets.memory = numBytes / g_audioInputFormat.mBytesPerPacket
        return noErr
    }

}
