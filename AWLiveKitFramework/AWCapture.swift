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
public enum AWLiveCaptureVideoQuality :Int,CustomStringConvertible, CustomDebugStringConvertible{
    case _480 = 0,_540i, _720, _720i, _1080, _4k
    public var sessionPreset : String {
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
    public func videoSizeForOrientation(_ orientation:AVCaptureVideoOrientation = .portrait) -> CGSize{
        switch self {
        case ._480:
            if orientation == .portrait || orientation == .portraitUpsideDown {
                return CGSize(width: 480.0, height: 640.0)
            }
            else {
                return CGSize(width: 640.0, height: 480.0)
            }
        case ._540i:
            if orientation == .portrait || orientation == .portraitUpsideDown {
                return CGSize(width: 540.0, height: 960.0)
            }
            else {
                return CGSize(width: 960.0, height: 540.0)
            }
        case ._720,._720i:
            if orientation == .portrait || orientation == .portraitUpsideDown {
                return CGSize(width: 720.0, height: 1280.0)
            }
            else {
                return CGSize(width: 1280.0, height: 720.0)
            }
        case ._1080:
            if orientation == .portrait || orientation == .portraitUpsideDown {
                return CGSize(width: 1080.0, height: 1920.0)
            }
            else {
                return CGSize(width: 1920.0, height: 1080.0)
            }
        case ._4k:
            if orientation == .portrait || orientation == .portraitUpsideDown {
                return CGSize(width: 2160.0, height: 3840.0)
            }
            else {
                return CGSize(width: 3840.0, height: 2160.0)
            }
        }
    }
    /// 对应码流
    public var recommandVideoBiterates : AWVideoEncoderBitrate {
        switch self {
        case ._480:
            return ._500kbs
        case ._540i:
            return ._800kbs
        case ._720,._720i:
            return ._1200kbs
        case ._1080:
            return ._2000kbs
        case ._4k:
            return ._4000kbs
        }
        
    }
    public var description: String {
        switch self {
        case ._480:
            return "480, 640x480, 500kbps"
        case ._540i:
            return "540i, 960x540, 800kbps"
        case ._720,._720i:
            return "720, 1280x720, 1200kbps"
        case ._1080:
            return "1080, 1920x1080, 2000kbps"
        case ._4k:
            return "4k, 3840x2160, 4000kbps"

        }
    }
    public var debugDescription: String {
        return self.description
    }
}

// MARK: - Capture
public typealias AWLiveCaptureSampleBufferCallback = (CMSampleBuffer) -> ()
public typealias AWLiveCaptureReadyCallback = () -> ()

public class AWLiveCapture : NSObject{
    /// session
    public var captureSession : AVCaptureSession!
    /// 设备
    fileprivate var videoDevice : AVCaptureDevice!
    fileprivate var audioDevice : AVCaptureDevice!
    /// 输入
    fileprivate var videoInput : AVCaptureInput!
    /// 输出
    fileprivate var videoOutput : AVCaptureVideoDataOutput!
    fileprivate var audioOutput : AVCaptureAudioDataOutput!
    /// 队列
    fileprivate var sessionQueue : DispatchQueue = DispatchQueue(label: "adow.live.session", attributes: [])
    fileprivate var videoQueue : DispatchQueue = DispatchQueue(label: "adow.live.video-queue", attributes: [])
    fileprivate var audioQueue : DispatchQueue = DispatchQueue(label: "adow.live.audio-queue", attributes: [])
    /// 获取视频采样内容后的回调
    public var onVideoSampleBuffer : AWLiveCaptureSampleBufferCallback? = nil
    /// 获取音频采样内容后的回调
    public var onAudioSampleBuffer : AWLiveCaptureSampleBufferCallback? = nil
    /// 准备好后发出回调
    public var onReady : AWLiveCaptureReadyCallback? = nil
    public var ready : Bool = false
    public init (sessionPreset:String = AVCaptureSessionPresetiFrame960x540, orientation : AVCaptureVideoOrientation = .portrait) {
        super.init()
//        let start_time = NSDate()
        /// session
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = sessionPreset ///AVCaptureSessionPresetiFrame960x540
        sessionQueue.async { 
            /// device
            self.videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            self.audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
            self.captureSession.beginConfiguration()
            defer {
                self.captureSession.commitConfiguration()
                /// 如果准备好了，发出回调
                if self.ready {
                    DispatchQueue.main.async(execute: { 
                        self.onReady?()
                    })
                }
            }
            /// input
            do {
                self.videoInput = try AVCaptureDeviceInput(device: self.videoDevice)
                self.captureSession.addInput(self.videoInput)
                let inputAudio = try AVCaptureDeviceInput(device: self.audioDevice)
                self.captureSession.addInput(inputAudio)
                
            }
            catch let error as NSError {
                NSLog("Input Device Error:%@", error)
            }
            /// videoOutput
            self.videoOutput = AVCaptureVideoDataOutput()
            self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
            let bgra = NSNumber(value: Int32(kCVPixelFormatType_32BGRA) as Int32)
            let captureSettings = [String(kCVPixelBufferPixelFormatTypeKey) : bgra]
            self.videoOutput.videoSettings = captureSettings
            self.videoOutput.alwaysDiscardsLateVideoFrames = false
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }
            else {
                NSLog("Can not add Video Output")
            }
            self.videoOrientation = orientation
    //        self.videoOrientation = .Portrait
            /// audioOutput
            self.audioOutput = AVCaptureAudioDataOutput()
            self.audioOutput.setSampleBufferDelegate(self, queue: self.audioQueue)
            if self.captureSession.canAddOutput(self.audioOutput) {
                self.captureSession.addOutput(self.audioOutput)
            }
            else {
                NSLog("Can not add Audio Output")
            }
            
            self.ready = true
        }
        
        
//        NSLog("Capture Setup duration:\(abs(start_time.timeIntervalSinceNow))")
    }
    /// 创建一个预览界面
    public var previewView : AWLivePreview {
        let view = AWLivePreview()
        view.session = self.captureSession
        if let layer = view.layer as? AVCaptureVideoPreviewLayer, let orientation = self.videoOrientation {
            layer.connection.videoOrientation = orientation
        }
        return view
    }
    /// 连接已经存在的 preview
    public func connectPreView(_ preview : AWLivePreview) {
        preview.session = self.captureSession
        if let layer = preview.layer as? AVCaptureVideoPreviewLayer, let orientation = self.videoOrientation {
            layer.connection.videoOrientation = orientation
        }
    }
    /// 设置横屏竖屏
    public var videoOrientation : AVCaptureVideoOrientation? {
        set {
            guard let _orientation = newValue else {
                return
            }
            let video_connection = videoOutput?.connection(withMediaType: AVMediaTypeVideo)
            video_connection?.videoOrientation = _orientation
        }
        get {
            let video_connection = videoOutput?.connection(withMediaType: AVMediaTypeVideo)
            return video_connection?.videoOrientation
        }
    }
    /// 屏幕镜像
    public var videoMirror : Bool? {
        set {
            guard let _mirror = newValue else {
                return
            }
            let video_connection = videoOutput.connection(withMediaType: AVMediaTypeVideo)
            video_connection?.isVideoMirrored = _mirror
        }
        get {
            let video_connection = videoOutput.connection(withMediaType: AVMediaTypeVideo)
            return video_connection?.isVideoMirrored
        }
    }
    /// 切换摄像头
    public var frontCammera : Bool{
        set {
            let position = newValue ? AVCaptureDevicePosition.front : AVCaptureDevicePosition.back
            do {
                self.captureSession.beginConfiguration()
                try self.videoDevice.lockForConfiguration()
                self.captureSession.removeInput(self.videoInput)
                self.videoDevice.unlockForConfiguration()
                self.videoDevice = nil
                if let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] {
                    if let camera = (devices.filter {
                        return $0.position == position
                    }).first {
                        self.videoDevice = camera
                        try camera.lockForConfiguration()
                        videoInput = try AVCaptureDeviceInput(device: camera)
                        self.captureSession.addInput(videoInput)
                        camera.unlockForConfiguration()
                    }
                }
                self.captureSession.commitConfiguration()
            
            }
            catch let error as NSError {
                NSLog("Input Device Error:%@", error)
                self.captureSession.commitConfiguration()
            }
        }
        get {
            return self.videoDevice.position == .front
        }
        
    }
}
// MARK: start and stop
extension AWLiveCapture {
    public func start() {
        guard self.ready else {
            NSLog("Capture is not ready")
            return
        }
        self.captureSession.startRunning()
    }
    public func stop() {
        guard self.captureSession.isRunning else {
            return
        }
        self.captureSession.stopRunning()
    }
}
// MARK: Video and Audio SampleBuffer
extension AWLiveCapture : AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if captureOutput == self.videoOutput {
            self.onVideoSampleBuffer?(sampleBuffer)
        }
        else if captureOutput == self.audioOutput {
            self.onAudioSampleBuffer?(sampleBuffer)
        }
    }
    public func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if captureOutput == videoOutput {
            print("Drop Video SampleBuffer")
        }
        else if captureOutput == audioOutput {
            print("Drop Audio SampleBuffer")
        }
    }
}

