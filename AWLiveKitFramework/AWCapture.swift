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
            return AVCaptureSession.Preset.vga640x480.rawValue
        case ._540i:
            return AVCaptureSession.Preset.iFrame960x540.rawValue
        case ._720:
            return AVCaptureSession.Preset.hd1280x720.rawValue
        case ._720i:
            return AVCaptureSession.Preset.iFrame1280x720.rawValue
        case ._1080:
            return AVCaptureSession.Preset.hd1920x1080.rawValue
        case ._4k:
            if #available(iOS 9.0, *) {
                return AVCaptureSession.Preset.hd4K3840x2160.rawValue
            } else {
                // 如果不支持的话还是使用 1920 * 1080
                return AVCaptureSession.Preset.hd1920x1080.rawValue
            }
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
    /// 前置摄像头
    var frontCameraDevice : AVCaptureDevice?
    /// 背后摄像头
    var backCameraDevice : AVCaptureDevice!
    /// 设备
    /// videoDevice 是 backCameraDevice(默认) 或者 frontCameraDevice(切换之后)
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
    fileprivate var fileQueue : DispatchQueue = DispatchQueue(label: "adow.live.output-2-queue", attributes: [])
    /// 获取视频采样内容后的回调
    public var onVideoSampleBuffer : AWLiveCaptureSampleBufferCallback? = nil
    /// 获取音频采样内容后的回调
    public var onAudioSampleBuffer : AWLiveCaptureSampleBufferCallback? = nil
    /// 准备好后发出回调
    public var onReady : AWLiveCaptureReadyCallback? = nil
    public var ready : Bool = false
    /// 文件输出
    fileprivate var fileOutput_1 : AVCaptureMovieFileOutput!
    fileprivate var fileOutput_2 : AVAssetWriter!
    fileprivate var fileOutput_2_video : AVAssetWriterInput!
    fileprivate var fileOutput_2_audio : AVAssetWriterInput!
    public init? (sessionPreset:String = AVCaptureSession.Preset.iFrame960x540.rawValue, orientation : AVCaptureVideoOrientation = .portrait) {
        super.init()
//        let start_time = NSDate()
        /// session
        captureSession = AVCaptureSession()
        guard captureSession.canSetSessionPreset(AVCaptureSession.Preset(rawValue: sessionPreset)) else {
            return nil
        }
        captureSession.sessionPreset = AVCaptureSession.Preset(rawValue: sessionPreset) ///AVCaptureSessionPresetiFrame960x540
        /// cameras
        let cameras = AVCaptureDevice.devices(for: AVMediaType.video)
        for one_camera in cameras {
            if one_camera.position == .back {
                if one_camera.supportsSessionPreset(AVCaptureSession.Preset(rawValue: sessionPreset)) {
                    self.backCameraDevice = one_camera
                    let ranges = self.backCameraDevice.activeFormat.videoSupportedFrameRateRanges
//                        debugPrint("ranges:\(String(describing: ranges))")
                    self.videoDevice = one_camera /// current video device is back camera
                }
                else {
                    /// TODO: Failed init because back camera
                    return nil
                }
            }
            else if one_camera.position == .front {
                if one_camera.supportsSessionPreset(AVCaptureSession.Preset(rawValue: sessionPreset)) {
                    self.frontCameraDevice = one_camera
                }
            }
        }
        
        /// audio
        self.audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)
        /// input and output
        sessionQueue.async {
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
                debugPrint("Input Device Error:%@", error)
                return
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
                debugPrint("Can not add Video Output")
                return
            }
    //        self.videoOrientation = .Portrait
            self.audioOutput = AVCaptureAudioDataOutput()
            self.audioOutput.setSampleBufferDelegate(self, queue: self.audioQueue)
            if self.captureSession.canAddOutput(self.audioOutput) {
                self.captureSession.addOutput(self.audioOutput)
            }
            else {
                debugPrint("Can not add Audio Output")
                return
            }
            /// 测试采集输出到文件
            /// fileOutput_1
//            self.fileOutput_1 = AVCaptureMovieFileOutput()
//            if self.captureSession.canAddOutput(self.fileOutput_1) {
//                self.captureSession.addOutput(self.fileOutput_1)
//            }
//            else {
//                NSLog("Can not add fileOutput_1")
//            }
            /// fileOutput_2
//            let output_2 = cache_dir.appending("/\(NSDate().timeIntervalSince1970).mov")
//            let output_2 = cache_dir.appending("/output_2.mov")
//            let output_2_url = URL(fileURLWithPath: output_2)
//            do {
//                NSLog("output_2:\(output_2_url)")
//                if FileManager.default.fileExists(atPath: output_2_url.path) {
////                    try FileManager.default.removeItem(at: output_2_url)
//                    try FileManager.default.removeItem(atPath: output_2_url.path)
//                    NSLog("remove output_2:\(output_2_url.path))")
//                }
//                self.fileOutput_2 = try AVAssetWriter(url: output_2_url, fileType: AVFileTypeQuickTimeMovie)
////                self.fileOutput_2.movieFragmentInterval = CMTimeMake(1, 1000)
//            }
//            catch let error {
//                NSLog("create fileOutput_2 error:\(error)")
//                return
//            }
//            /// video
//            if var fileOutput_2_video_setting = self.videoOutput?.recommendedVideoSettingsForAssetWriter(withOutputFileType: AVFileTypeQuickTimeMovie) as? [String:Any]{
//                fileOutput_2_video_setting[AVVideoCodecKey] = AVVideoCodecH264
//                NSLog("video settings:\(fileOutput_2_video_setting)")
//                self.fileOutput_2_video =
//                    AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: fileOutput_2_video_setting)
//                self.fileOutput_2_video.expectsMediaDataInRealTime = true
//                if self.fileOutput_2.canAdd(self.fileOutput_2_video) {
//                    self.fileOutput_2.add(self.fileOutput_2_video)
//                }
//                else {
//                    NSLog("output_2 add video input failed")
//                }
//            }
//            /// audio
//            if let fileOutput_2_audio_setting = self.audioOutput?.recommendedAudioSettingsForAssetWriter(withOutputFileType: AVFileTypeQuickTimeMovie) as? [String:Any] {
//                NSLog("audio settings:\(fileOutput_2_audio_setting)")
//                self.fileOutput_2_audio = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: fileOutput_2_audio_setting)
//                self.fileOutput_2_audio.expectsMediaDataInRealTime = true
//                if self.fileOutput_2.canAdd(self.fileOutput_2_audio) {
//                    self.fileOutput_2.add(self.fileOutput_2_audio)
//                }
//                else {
//                    NSLog("output_2 add audio input failed")
//                }
//                
//            }
            ///
            self.videoOrientation = orientation
            /// ready
            self.ready = true
        }
        
        
//        NSLog("Capture Setup duration:\(abs(start_time.timeIntervalSinceNow))")
    }
    /// 创建一个预览界面
    public var previewView : AWLivePreview {
        let view = AWLivePreview()
        view.session = self.captureSession
        if let layer = view.layer as? AVCaptureVideoPreviewLayer, let orientation = self.videoOrientation {
            layer.connection?.videoOrientation = orientation
        }
        return view
    }
    /// 连接已经存在的 preview
    public func connectPreView(_ preview : AWLivePreview) {
        preview.session = self.captureSession
        if let layer = preview.layer as? AVCaptureVideoPreviewLayer, let orientation = self.videoOrientation {
            layer.connection?.videoOrientation = orientation
        }
    }
    /// 设置横屏竖屏
    public var videoOrientation : AVCaptureVideoOrientation? {
        set {
            guard let _orientation = newValue else {
                return
            }
            /// 内容输出
            if let video_connection = self.videoOutput?.connection(with: AVMediaType.video) {
                video_connection.videoOrientation = _orientation
            }
            /// 文件输出
            if let file_connection = self.fileOutput_1?.connection(with: AVMediaType.video) {
                file_connection.videoOrientation = _orientation;
            }
        }
        get {
            let video_connection = videoOutput?.connection(with: AVMediaType.video)
            return video_connection?.videoOrientation
        }
    }
    /// 屏幕镜像
    public var videoMirror : Bool? {
        set {
            guard let _mirror = newValue else {
                return
            }
            let video_connection = videoOutput.connection(with: AVMediaType.video)
            video_connection?.isVideoMirrored = _mirror
        }
        get {
            let video_connection = videoOutput.connection(with: AVMediaType.video)
            return video_connection?.isVideoMirrored
        }
    }
    /// 切换摄像头
    public var useFrontCammera : Bool{
        set {
            guard useFrontCammera != newValue else {
                return
            }
            guard let _frontCamera = self.frontCameraDevice else {
                debugPrint("front camera is not supported")
                return
            }
            do {
                self.captureSession.beginConfiguration()
                /// remove
                try self.videoDevice.lockForConfiguration()
                self.captureSession.removeInput(self.videoInput)
                self.videoDevice.unlockForConfiguration()
                self.videoDevice = nil
                /// set
                self.videoDevice = newValue ? _frontCamera : self.backCameraDevice
                try self.videoDevice.lockForConfiguration()
                videoInput = try AVCaptureDeviceInput(device: self.videoDevice)
                self.captureSession.addInput(videoInput)
                self.videoDevice.unlockForConfiguration()
                ///
                self.captureSession.commitConfiguration()
            
            }
            catch let error as NSError {
                debugPrint("Input Device Error:%@", error)
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
            debugPrint("Capture is not ready")
            return
        }
        self.captureSession.startRunning()
        /// output_1
        let output_1 = cache_dir.appending("/output_1.mov")
        let output_1_url = URL(fileURLWithPath: output_1)
        self.fileOutput_1?.startRecording(to: output_1_url, recordingDelegate: self)
        /// output_2
//        self.fileOutput_2?.startWriting()
    }
    public func stop() {
        guard self.captureSession.isRunning else {
            return
        }
        self.captureSession.stopRunning()
        /// output_1
        self.fileOutput_1?.stopRecording()
        /// output_2
        self.fileOutput_2_video?.markAsFinished()
        self.fileOutput_2_audio?.markAsFinished()
        self.fileOutput_2?.finishWriting {
            debugPrint("finish output_2")
        }
    }
    /// 测试可以使用哪些 session_preset
    func testSessionPreset() {
        var session_preset_list : [String:String] = [ "AVCaptureSessionPresetPhoto":AVCaptureSession.Preset.photo.rawValue,
                 "AVCaptureSessionPresetHigh": AVCaptureSession.Preset.high.rawValue,
                 "AVCaptureSessionPresetMedium":
                    AVCaptureSession.Preset.medium.rawValue,
                 "AVCaptureSessionPresetLow":AVCaptureSession.Preset.low.rawValue,
                 "AVCaptureSessionPreset352x288":
                    AVCaptureSession.Preset.cif352x288.rawValue,
                 "AVCaptureSessionPreset640x480":
                    AVCaptureSession.Preset.vga640x480.rawValue,
                 "AVCaptureSessionPreset1280x720":
                    AVCaptureSession.Preset.hd1280x720.rawValue,
                 "AVCaptureSessionPreset1920x1080"
                    :AVCaptureSession.Preset.hd1920x1080.rawValue,
                 "AVCaptureSessionPresetiFrame960x540"
                    :AVCaptureSession.Preset.iFrame960x540.rawValue,
                 "AVCaptureSessionPresetiFrame1280x720"
                    :AVCaptureSession.Preset.iFrame1280x720.rawValue,
                 "AVCaptureSessionPresetInputPriority":
                    AVCaptureSession.Preset.inputPriority.rawValue,
            
        ]
        if #available(iOS 9.0, *) {
            session_preset_list["AVCaptureSessionPreset3840x2160"] = AVCaptureSession.Preset.hd4K3840x2160.rawValue
        } else {
            // Fallback on earlier versions
        }
        session_preset_list.forEach { (k,v) in
            let result = self.captureSession.canSetSessionPreset(AVCaptureSession.Preset(rawValue: v))
            debugPrint("\(k):\(result)")
        }
        
    }
}
// MARK: Video and Audio SampleBuffer
extension AWLiveCapture : AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if captureOutput == self.videoOutput {
            self.onVideoSampleBuffer?(sampleBuffer)
            
        }
        else if captureOutput == self.audioOutput {
            self.onAudioSampleBuffer?(sampleBuffer)
        }
        /// output_2
        guard let writer = self.fileOutput_2, let video_input = self.fileOutput_2_video, let audio_input = self.fileOutput_2_audio else {
            return
        }
        if writer.status == .unknown{
            if writer.startWriting() {
                let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    //            let time = kCMTimeZero
                writer.startSession(atSourceTime: time)
                debugPrint("writer started:\(time)")
            }
            else {
                writer.finishWriting {
                    
                }
                debugPrint("writer start failed:\(writer.error?.localizedDescription ?? "")")
            }
        }
        else if writer.status == .writing {
            if captureOutput == self.audioOutput {
                fileQueue.async {
                    if audio_input.isReadyForMoreMediaData {
                        if audio_input.append(sampleBuffer) {
                            debugPrint("write audio ok")
                        }
                        else {
                            debugPrint("write audio failed")
                        }
                    }
                    else {
                        debugPrint("audio writer not ready")
                    }
                }
            }
            else if captureOutput == self.videoOutput {
                fileQueue.async {
                    if video_input.isReadyForMoreMediaData {
                        if video_input.append(sampleBuffer) {
                            debugPrint("write video ok")
                        }
                        else {
                            debugPrint("write video failed")
                        }
                    }
                    else {
                        debugPrint("video writer not ready")
                    }
                }    
            }
            
        }
        else {
            NSLog("writer status:\(writer.status.rawValue),\(writer.error?.localizedDescription  ?? "")")
        }
    }
    public func captureOutput(_ captureOutput: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if captureOutput == videoOutput {
            print("Drop Video SampleBuffer")
        }
        else if captureOutput == audioOutput {
            print("Drop Audio SampleBuffer")
        }
    }
}
extension AWLiveCapture : AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ captureOutput: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        NSLog("start save outputFile_1:\(fileURL)")
    }
    public func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        NSLog("stop outputFile_1:\(outputFileURL)")
        self.captureSession.removeOutput(captureOutput)
    }
}

