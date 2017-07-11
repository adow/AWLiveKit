//
//  AWLive.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/1/3.
//  Copyright © 2017年 秦 道平. All rights reserved.
//


import Foundation
import UIKit
import AVFoundation

public class AWLive {
    public var push : AWLivePush2!
    public var capture : AWLiveCapture!
    public var videoEncoder : AWVideoEncoder!
    public var audioEncoder : AWAudioEncoder!
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
        push = AWLivePush2(url: url)
        push.delegate = self
        /// capture
        capture = AWLiveCapture(sessionPreset: videoQuality.sessionPreset,
                                orientation: orientation)
        if capture == nil {
            NSLog("AVLiveCapture failed")
            return nil
        }
        capture.onVideoSampleBuffer = {
            [weak self](sampleBuffer) -> () in
            self?.videoEncoder?.encodeSampleBuffer(sampleBuffer)
            
        }
        capture.onAudioSampleBuffer = {
            [weak self](sampleBuffer) -> () in
            //            print("audio")
            self?.audioEncoder?.encodeSampleBuffer(sampleBuffer)
//            aw_audio_encode_samplebuffer(sampleBuffer)
        }
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
        self.close()
        NotificationCenter.default.removeObserver(self)
        NSLog("AWLive release")
    }
    fileprivate func close() {
        self.stopLive()
        self.push.disconnect()
        self.capture?.stop()
    }
}
extension AWLive {
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
extension AWLive {
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
extension AWLive {
    /// 开始直播，指定当前的旋转位置, 只有开始直播的时候才进行编码
    public func startLive() {
        guard let orientation = self.videoOrientation else {
            NSLog("No Video Orientation")
            return
        }
        /// videoEncoder
        videoEncoder?.close()
        videoEncoder = nil
        videoEncoder = AWVideoEncoder(outputSize: videoQuality.videoSizeForOrientation(orientation),
                                      bitrate: videoQuality.recommandVideoBiterates,
                                      fps:videoQuality.recommandVideoBiterates.recommandedFPS,
                                      profile: videoQuality.recommandVideoBiterates.recommandedProfile)
        videoEncoder.onEncoded = {
            [weak self](sampleBuffer) -> () in
            //            print("video encoded")
            self?.push?.pushVideoSampleBuffer(sampleBuffer) /// push
        }
        /// audioEncoder
        audioEncoder = AWAudioEncoder()
        audioEncoder.onEncoded = {
            [weak self](bufferList) -> () in
            self?.push?.pushAudioBufferList(bufferList) /// push
        }
        self.push?.start()
        ///
        self.liveStat?.start()
    }
    public func stopLive() {
        self.liveStat?.stop()
        self.push?.stop()
        self.videoEncoder?.close()
        self.videoEncoder = nil
        self.audioEncoder = nil
    }
}
extension AWLive : AWLivePushDeletate {
    public func push(_ push: AWLivePush2, connectedStateChanged state: AWLiveConnectState) {
        NSLog("push connect changed:\(state)")
    }
    public func pushLiveChanged(_ push: AWLivePush2) {
        NSLog("push live changed:\(push.isLive)")
    }
}
extension AWLive {
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
        self.close()
    }
}

