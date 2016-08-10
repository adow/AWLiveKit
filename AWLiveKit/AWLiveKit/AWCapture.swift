//
//  AWCapture.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 16/8/8.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - VideoQuality
enum AWLiveCaptureVideoQuality :Int{
    case _480 = 0,_540i, _720, _720i, _1080, _4k
    var sessionPreset : String {
        switch self {
        case ._480:
            return AVCaptureSessionPreset640x480
        case ._540i:
            return AVCaptureSessionPresetiFrame960x540
        case ._720:
            return AVCaptureSessionPreset1280x720
        case ._720i:
            return AVCaptureSessionPresetiFrame1280x720
        case ._1080:
            return AVCaptureSessionPreset1920x1080
        case ._4k:
            return AVCaptureSessionPreset3840x2160
        }
    }
    /// 输出视频
    func videoSizeForOrientation(orientation:AVCaptureVideoOrientation = .Portrait) -> CGSize{
        switch self {
        case ._480:
            if orientation == .Portrait || orientation == .PortraitUpsideDown {
                return CGSizeMake(480.0, 640.0)
            }
            else {
                return CGSizeMake(640.0, 480.0)
            }
        case ._540i:
            if orientation == .Portrait || orientation == .PortraitUpsideDown {
                return CGSizeMake(540.0, 960.0)
            }
            else {
                return CGSizeMake(960.0, 540.0)
            }
        case ._720,_720i:
            if orientation == .Portrait || orientation == .PortraitUpsideDown {
                return CGSizeMake(720.0, 1280.0)
            }
            else {
                return CGSizeMake(1780.0, 720.0)
            }
        case ._1080:
            if orientation == .Portrait || orientation == .PortraitUpsideDown {
                return CGSizeMake(1080.0, 1920.0)
            }
            else {
                return CGSizeMake(1920.0, 1080.0)
            }
        case ._4k:
            if orientation == .Portrait || orientation == .PortraitUpsideDown {
                return CGSizeMake(2160.0, 3840.0)
            }
            else {
                return CGSizeMake(3840.0, 2160.0)
            }
        }
    }
    /// 对应码流
    var recommandVideoBiterates : AWVideoEncoderBitrate {
        switch self {
        case ._480:
            return ._500kbs
        case ._540i:
            return ._800kbs
        case ._720,._720i:
            return ._1000kbs
        case ._1080:
            return ._2000kbs
        case ._4k:
            return ._4000kbs
        }
        
    }
}

// MARK: - Capture
typealias AWLiveCaptureSampleBufferCallback = (CMSampleBuffer) -> ()


class AWLiveCapture : NSObject{
    private var videoQuality : AWLiveCaptureVideoQuality = ._540i
    /// session
    private var captureSession : AVCaptureSession!
    /// 设备
    private var videoDevice : AVCaptureDevice!
    private var audioDevice : AVCaptureDevice!
    /// 输出
    private var videoOutput : AVCaptureVideoDataOutput!
    private var audioOutput : AVCaptureAudioDataOutput!
    /// 队列
    private var sessionQueue : dispatch_queue_t = dispatch_queue_create("adow.live.session", DISPATCH_QUEUE_SERIAL)
    private var videoQueue : dispatch_queue_t = dispatch_queue_create("adow.live.video-queue", DISPATCH_QUEUE_SERIAL)
    private var audioQueue : dispatch_queue_t = dispatch_queue_create("adow.live.audio-queue", DISPATCH_QUEUE_SERIAL)
    /// 获取视频采样内容后的回调
    var onVideoSampleBuffer : AWLiveCaptureSampleBufferCallback? = nil
    /// 获取音频采样内容后的回调
    var onAudioSampleBuffer : AWLiveCaptureSampleBufferCallback? = nil
    
    init (videoQuality : AWLiveCaptureVideoQuality = ._540i, orientation : AVCaptureVideoOrientation = .Portrait) {
        super.init()
        NSLog("Capture size:\(videoQuality.rawValue)")
        self.videoQuality = videoQuality
        /// session
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = self.videoQuality.sessionPreset ///AVCaptureSessionPresetiFrame960x540
        /// device
        self.videoDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        self.audioDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
        self.captureSession.beginConfiguration()
        defer {
            self.captureSession.commitConfiguration()
        }
        /// input
        do {
            let inputVideo = try AVCaptureDeviceInput(device: self.videoDevice)
            self.captureSession.addInput(inputVideo)
            let inputAudio = try AVCaptureDeviceInput(device: self.audioDevice)
            self.captureSession.addInput(inputAudio)
            
        }
        catch let error as NSError {
            NSLog("Input Device Error:%@", error)
        }
        /// videoOutput
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
        let bgra = NSNumber(int: Int32(kCVPixelFormatType_32BGRA))
        let captureSettings = [String(kCVPixelBufferPixelFormatTypeKey) : bgra]
        videoOutput.videoSettings = captureSettings
        videoOutput.alwaysDiscardsLateVideoFrames = false
        if self.captureSession.canAddOutput(self.videoOutput) {
            self.captureSession.addOutput(self.videoOutput)
        }
        else {
            NSLog("Can not add Video Output")
        }
        self.videoOrientation = orientation
//        self.videoOrientation = .Portrait
        /// audioOutput
        audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: self.audioQueue)
        if self.captureSession.canAddOutput(audioOutput) {
            self.captureSession.addOutput(audioOutput)
        }
        else {
            NSLog("Can not add Audio Output")
        }
    }
    /// 预览界面
    var previewView : AWLivePreview {
        let view = AWLivePreview()
        view.session = self.captureSession
        return view
    }
    /// 设置横屏竖屏
    var videoOrientation : AVCaptureVideoOrientation? {
        set {
            guard let _orientation = newValue else {
                return
            }
            let video_connection = videoOutput.connectionWithMediaType(AVMediaTypeVideo)
            video_connection?.videoOrientation = _orientation
        }
        get {
            let video_connection = videoOutput.connectionWithMediaType(AVMediaTypeVideo)
            return video_connection?.videoOrientation
        }
    }
    /// 屏幕镜像
    var videoMirror : Bool? {
        set {
            guard let _mirror = newValue else {
                return
            }
            let video_connection = videoOutput.connectionWithMediaType(AVMediaTypeVideo)
            video_connection?.videoMirrored = _mirror
        }
        get {
            let video_connection = videoOutput.connectionWithMediaType(AVMediaTypeVideo)
            return video_connection?.videoMirrored
        }
    }
}
// MARK: start and stop
extension AWLiveCapture {
    func start() {
        self.captureSession.startRunning()
    }
    func stop() {
        self.captureSession.stopRunning()
    }
}
// MARK: Video and Audio SampleBuffer
extension AWLiveCapture : AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if captureOutput == self.videoOutput {
            self.onVideoSampleBuffer?(sampleBuffer)
        }
        else if captureOutput == self.audioOutput {
            self.onAudioSampleBuffer?(sampleBuffer)
        }
    }
    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if captureOutput == videoOutput {
            print("Drop Video SampleBuffer")
        }
        else if captureOutput == audioOutput {
            print("Drop Audio SampleBuffer")
        }
    }
}

