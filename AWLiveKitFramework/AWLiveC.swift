//
//  AWLiveC.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/7/14.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

public class AWLiveC {
    public var push : AWLivePushC!
    public var capture : AWLiveCapture!
    public weak var preview : AWLivePreview?
    public var videoQuality : AWLiveCaptureVideoQuality!
    /// 请求权限后的返回结果
    public var requestCaptureCallback : ((Bool,String?)->())? = nil
    public var isLive : Bool? {
        return self.push?.isLive
    }
    public var isInterruption : Bool = false
    /// 状态监控
    public var liveStat : AWLiveStat!
    
    public init?(url:String,
                 onPreview preview : AWLivePreview,
                 withQuality videoQuality : AWLiveCaptureVideoQuality = AWLiveCaptureVideoQuality._720,
                 atOrientation orientation : AVCaptureVideoOrientation = .portrait) {
        self.videoQuality = videoQuality
        self.preview = preview
       
        
        /// push
        push = AWLivePushC(url: url)
        push.delegate = self
        /// capture
        capture = AWLiveCapture(sessionPreset: videoQuality.sessionPreset,
                                orientation: orientation)
        if capture == nil {
            NSLog("AVLiveCapture failed")
            return nil
        }
        /// video encoder
        //self.openVideoEncoder()
        ///
        capture.onVideoSampleBuffer = {
            [weak self](sampleBuffer) -> () in
            /// 只有在推流开始的时候才进行编码
            guard let _self = self, let _push = _self.push, _push.isLive else {
                return
            }
            let ret = aw_video_encode_samplebuffer(sampleBuffer, { (sample_buffer_encoded, context) in
                if let sp = sample_buffer_encoded {
                    NSLog("video encoded")
                    //NSLog("video encoded:\(sp)")
                    let _weak_push = unsafeBitCast(context, to: AWLivePushC.self)
                    _weak_push.pushVideoSampleBuffer(sp)
                }
                else {
                    NSLog("video not encoded")
                }
                
            }, unsafeBitCast(_push, to: UnsafeMutableRawPointer.self))
            
            if ret < 0 {
                self?.liveStat.videoEncoderError = "视频编码错误:\(ret)"
            }
            
        }
        capture.onAudioSampleBuffer = {
            [weak self](sampleBuffer) -> () in
            /// 只有在推流开始的时候才进行编码
            guard let _self = self, let _push = _self.push, _push.isLive else {
                return
            }
            let buffer_list = aw_audio_encode(sampleBuffer)
            if let _buffer_list = buffer_list {
                NSLog("audio encoded")
                /// push
                _push.pushAudioBufferList(_buffer_list.pointee)
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
            
            _self.capture.connectPreView(preview)
            _self.capture.start()
        }
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
        /// 通知视频捕捉
        self.capture?.stop()
        NotificationCenter.default.removeObserver(self)
        NSLog("AWLive release")
    }
    
}
extension AWLiveC {
    public var videoOrientation : AVCaptureVideoOrientation? {
        set {
            if let _orientation = newValue {
                self.preview?.videoOrientation = _orientation
                self.capture?.videoOrientation = _orientation
            }
        }
        get {
            return self.capture?.videoOrientation
        }
    }
    /// 设置当前的屏幕方向
    public func rotateWithCurrentOrientation() {
        let device_orientation = UIApplication.shared.statusBarOrientation
        switch device_orientation {
        case .landscapeLeft:
            self.videoOrientation = .landscapeLeft
        case .landscapeRight:
            self.videoOrientation = .landscapeRight
        case .portrait:
            self.videoOrientation = .portrait
        case .portraitUpsideDown:
            self.videoOrientation = .portraitUpsideDown
        default:
            self.videoOrientation = .portrait
        }
    }
    public var useFrontCamera : Bool {
        set {
            self.capture.useFrontCammera = newValue
            self.rotateWithCurrentOrientation()
        }
        get {
            return self.capture.useFrontCammera
        }
    }
    /// 是否可以使用前置摄像头
    public var canUseFrontCamera : Bool {
        return self.capture.frontCameraDevice != nil
    }
    public var mirror : Bool? {
        set {
            if let _mirror = newValue {
                self.capture.videoMirror = _mirror
                self.preview?.mirror = _mirror
            }
        }
        get {
            return self.capture.videoMirror
        }
    }
}
extension AWLiveC {
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
extension AWLiveC {
    /// 开始视频编码器
    func startVideoEncoder() {
        /// 视频编码器
        let video_size = videoQuality.videoSizeForOrientation(videoOrientation!)
        let ret = aw_video_encoder_init(Int32(video_size.width),
                                        Int32(video_size.height),
                                        Int32(videoQuality.recommandVideoBiterates.bitrates),
                                        Int32(videoQuality.recommandVideoBiterates.recommandedFPS.fps),
                                        videoQuality.recommandVideoBiterates.recommandedProfile.profile)
        NSLog("ret:\(ret)")
    }
    /// 关闭视频编码器
    func stopVideoEncoder() {
        aw_video_encoder_close()
    }
    /// 开始直播，指定当前的旋转位置, 只有开始直播的时候才进行编码
    public func startLive() {
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
extension AWLiveC : AWLivePushDeletate {
    public func pushError(_ code: Int, withMessage message: String) {
        
    }

    public func push(_ push: AWLivePushC, connectedStateChanged state: AWLiveConnectState) {
        NSLog("push connect changed:\(state)")
    }
    public func pushLiveChanged(_ push: AWLivePushC) {
        NSLog("push live changed:\(push.isLive)")
    }
    public func resetPushError() {
        
    }
}
extension AWLiveC {
    @objc fileprivate func onNotificationEnterForeground(_ notification:Notification) {
        if self.isInterruption {
            self.isInterruption = false
            self.startLive()
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
