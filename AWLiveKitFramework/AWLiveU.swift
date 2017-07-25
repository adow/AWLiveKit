//
//  AWLiveU.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/7/24.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

// MARK: - AWLiveBase
public class AWLiveBase {
    public var push : AWLivePushC!
    public var videoQuality : AWLiveCaptureVideoQuality!
    public var orientation : AVCaptureVideoOrientation!
    /// 请求权限后的返回结果
    public var requestCaptureCallback : ((Bool,String?)->())? = nil
    public var isLive : Bool? {
        return self.push?.isLive
    }
    public var isInterruption : Bool = false
    /// 状态监控
    public var liveStat : AWLiveStat!
    
    public required init?(url:String,
                 withQuality videoQuality : AWLiveCaptureVideoQuality = ._720,
                 atOrientation orientation: AVCaptureVideoOrientation = .portrait) {
        
        self.videoQuality = videoQuality
        self.orientation = orientation
        /// push
        push = AWLivePushC(url: url)
        push.delegate = self
        
        ///
        self.liveStat = AWLiveStat()
        /// notification
        NotificationCenter.default.addObserver(self,
                selector: #selector(onNotificationResign(_:)),
                name: NSNotification.Name.UIApplicationWillResignActive,
                object: nil)
        NotificationCenter.default.addObserver(self,
                selector: #selector(onNotificationEnterForeground(_:)),
                name: NSNotification.Name.UIApplicationDidBecomeActive,
                object: nil)
        NotificationCenter.default.addObserver(self,
                selector: #selector(onNotificationTerminate(_:)),
                name: NSNotification.Name.UIApplicationWillTerminate,
                object: nil)
    }
    deinit {
        /// 关闭直播
        self.stopLive()
        /// 关闭视频编码器
        aw_video_encoder_close()
        NotificationCenter.default.removeObserver(self)
        NSLog("AWLiveBase release")
    }
    public func switchCamera() {
        
    }
    public var connectedPreview : UIView? {
        get {
            return nil
        }
    }
    public var beauty : Int = 0
    public func startCapture() {
        
    }
    /// 获取摄像头权限
    public static func requestCapture(callback:@escaping ((Bool,String?)->())) {
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) { (succeed_video) in
            if succeed_video {
                AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeAudio, completionHandler: { (succeed_audio) in
                    if succeed_audio {
                        DispatchQueue.main.async(execute: {
                            callback(true,nil)
                        })
                    }
                    else {
                        DispatchQueue.main.async(execute: {
                            callback(false,"无法获取麦克风，请在设置中打开麦克风权限")
                        })
                    }
                })
            }
            else {
                DispatchQueue.main.async(execute: {
                    callback(false,"无法获取摄像头，请在设置中获取摄像头权限")
                })
            }
        }
    }
    
}
extension AWLiveBase {
    /// 是否已经完成连接
    public var isConnected : Bool {
        if let _push = self.push {
            return _push.connectState == .Connected
        }
        else {
            return false
        }
    }
    public func startLive() {
        /// 检查连接
        guard self.isConnected else {
            return
        }
        /// 开始运行视频编码器
        self.startVideoEncoder()
        /// 开始推流
        self.push?.start()
        /// 开始状态数据检测
        self.liveStat?.start()   
    }
    public func stopLive() {
        /// 结束运行视频编码器
        self.stopVideoEncoder()
        /// 结束推流
        self.push?.stop()
        /// 停止状态数据检测
        self.liveStat?.stop()
    }
    
}
extension  AWLiveBase {
    func startVideoEncoder() {
        /// 视频编码器
        let video_size = videoQuality.videoSizeForOrientation(orientation)
        let ret = aw_video_encoder_init(Int32(video_size.width),
                Int32(video_size.height),
                Int32(videoQuality.recommandVideoBiterates.bitrates),
                Int32(videoQuality.recommandVideoBiterates.recommandedFPS.fps),
                videoQuality.recommandVideoBiterates.recommandedProfile.profile)
        NSLog("ret:\(ret)")
    }
    func stopVideoEncoder() {
        aw_video_encoder_close()
    }
}
extension AWLiveBase:AWLivePushDeletate {
    public func push(_ push: AWLivePushC, connectedStateChanged state: AWLiveConnectState) {
        NSLog("push connect changed:\(state)")
    }
    public func pushLiveChanged(_ push: AWLivePushC) {
        NSLog("push live changed:\(push.isLive)")
    }
    public func pushError(_ code: Int, withMessage message: String) {
        
    }
    public func resetPushError() {
        
    }
}
extension AWLiveBase {
    @objc fileprivate func onNotificationEnterForeground(_ notification:Notification) {
        if self.isInterruption {
            self.isInterruption = false
            //self.startLive()
        }
    }
    @objc fileprivate func onNotificationResign(_ notification:Notification) {
        if let _isLive = self.isLive , _isLive{
            self.stopLive()
            self.isInterruption = true
        }
    }
    @objc fileprivate func onNotificationTerminate(_ notification:Notification) {
    }
}

// MARK: - AWLiveSimple
public class AWLiveSimple : AWLiveBase {
    public var capture : AWLiveCapture!
    public var preview: AWLivePreview!
    public required init?(url:String,
                 withQuality videoQuality : AWLiveCaptureVideoQuality = ._720,
                 atOrientation orientation: AVCaptureVideoOrientation = .portrait) {
        super.init(url: url, withQuality: videoQuality, atOrientation: orientation)
        preview = AWLivePreview()
        preview.videoOrientation = orientation
        /// capture
        capture = AWLiveCapture(sessionPreset: videoQuality.sessionPreset, orientation: orientation)
        if capture == nil {
            NSLog("AVLiveCapture failed")
            return nil
        }
        ///
        capture.onVideoSampleBuffer = {
            [weak self](sampleBuffer) -> () in
            /// 只有在推流开始的时候才进行编码
            guard let _self = self else {
                return
            }
            let ret = aw_video_encode_samplebuffer(sampleBuffer, { (sample_buffer_encoded, context) in
                if let sp = sample_buffer_encoded {
                    NSLog("video encoded")
                    //NSLog("video encoded:\(sp)")
                    let _weak_self = unsafeBitCast(context, to: AWLiveBase.self)
                    let _weak_push = _weak_self.push
                    if let _live = _weak_push?.isLive, _live {
                        _weak_push?.pushVideoSampleBuffer(sp)
                    }
                }
                else {
                    NSLog("video not encoded")
                }
                
            }, unsafeBitCast(_self, to: UnsafeMutableRawPointer.self))
            
            if ret < 0 {
                self?.liveStat?.videoEncoderError = "视频编码错误:\(ret)"
            }
            else {
                self?.liveStat?.videoEncoderError = nil
            }
            
        }
        capture.onAudioSampleBuffer = {
            [weak self](sampleBuffer) -> () in
            /// 只有在推流开始的时候才进行编码
            guard let _self = self else {
                return
            }
            let buffer_list = aw_audio_encode(sampleBuffer)
            if let _buffer_list = buffer_list {
                NSLog("audio encoded")
                /// push
                if let _live = _self.push?.isLive, _live {
                    _self.push?.pushAudioBufferList(_buffer_list.pointee)
                }
                aw_audio_release(_buffer_list)
                _self.liveStat?.audioEncoderError = nil
            }
            else {
                NSLog("audio not encoded")
                _self.liveStat?.audioEncoderError = "音频编码错误"
            }
            
        }
        /// 准备好了再开始捕捉
        capture.onReady = {
            [weak self] in
            guard let _self = self else {
                return
            }
            
            _self.capture.connectPreView(_self.preview)
            _self.capture.start()
        }
    }
    deinit {
        self.capture?.stop()
    }
    public override func switchCamera() {
        super.switchCamera()
        if let _capture = self.capture {
            if _capture.frontCameraDevice == nil {
                return
            }
            else {
                _capture.useFrontCammera = !(_capture.useFrontCammera)
            }
            _capture.videoOrientation = self.orientation
        }
    }
    override public var connectedPreview: UIView? {
        return self.preview
    }
    override public var beauty: Int {
        get {
            return 0
        }
        set {
            
        }
    }
    override public func startCapture() {
        //self.capture?.start()
    }
}
// MARK: - AWLiveBeauty
public class AWLiveBeauty : AWLiveBase {
    public var capture : AWGPUImageCapture!
    public var preview : GPUImageView!
    public required init?(url:String,
                 withQuality videoQuality : AWLiveCaptureVideoQuality = ._720,
                 atOrientation orientation: AVCaptureVideoOrientation = .portrait) {
        super.init(url: url, withQuality: videoQuality, atOrientation: orientation)
        ///
        preview = GPUImageView()
        capture =
            AWGPUImageCapture(sessionPreset: videoQuality.sessionPreset,
                orientation: UIInterfaceOrientation(rawValue:orientation.rawValue)!,
                preview: preview)
        if capture == nil {
            NSLog("AWGPUImageCapture failed")
        }
        capture.onAudioSampleBuffer = {
            [weak self] (sampleBuffer) -> () in
            guard let _self = self else {
                return
            }
            //            NSLog("audio sample buffer")
            if let buffer_list = aw_audio_encode(sampleBuffer) {
                //NSLog("audio buffer list:\(buffer_list)")
                NSLog("audio buffer list encoded")
                if let _live = _self.push?.isLive, _live {
                    _self.push.pushAudioBufferList(buffer_list.pointee)
                }
                aw_audio_release(buffer_list)
                _self.liveStat?.audioEncoderError = nil
            }
            else {
                NSLog("no audio encoded")
                _self.liveStat?.audioEncoderError = "音频编码错误"
            }
            
        }
        capture.onVideoPixelBuffer = {
            [weak self](pixelBuffer, presentation_time, duration) -> () in
            guard let _self = self else {
                return
            }
//            NSLog("video sample buffer")
            let ret = aw_video_encode_pixelbuffer(pixelBuffer, presentation_time, duration, { (sample_buffer, context) in
                if let _p = sample_buffer {
                    //NSLog("video sample buffer encoded:\(_p)")
                    NSLog("video sample buffer encoded")
                    let _weak_push = unsafeBitCast(context, to: AWLivePushC.self)
                    if _weak_push.isLive {
                        _weak_push.pushVideoSampleBuffer(_p)
                    }
                    
                }
                else {
                    NSLog("no video encoded")
                }
                
            }, unsafeBitCast(_self.push, to: UnsafeMutableRawPointer.self))
            if ret < 0 {
                self?.liveStat?.videoEncoderError = "视频编码错误:\(ret)"
            }
            else {
                self?.liveStat?.videoEncoderError = nil
            }
        }
        //capture.start()
    }
    deinit {
        self.capture?.stop()
    }
    public override func switchCamera() {
        super.switchCamera()
        self.capture?.camera?.rotateCamera()
    }
    public override var connectedPreview: UIView? {
        return self.preview
    }
    public override var beauty: Int {
        get {
            return self.capture?.beauty ?? 0
        }
        set {
            self.capture?.beauty = newValue
        }
    }
    public override func startCapture() {
        self.capture?.start()
    }
}
