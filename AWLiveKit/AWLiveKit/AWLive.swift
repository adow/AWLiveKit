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

class AWLive {
    var push : AWLivePush2!
    var capture : AWLiveCapture!
    var videoEncoder : AWVideoEncoder!
    var audioEncoder : AWAudioEncoder!
    weak var preview : AWLivePreview?
    var videoQuality : AWLiveCaptureVideoQuality!
    var isLive : Bool? {
        return self.push?.isLive
    }
    var isInterruption : Bool = false
    init(url:String,
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
        capture.onVideoSampleBuffer = {
            [weak self](sampleBuffer) -> () in
            self?.videoEncoder?.encodeSampleBuffer(sampleBuffer)
            
        }
        capture.onAudioSampleBuffer = {
            [weak self](sampleBuffer) -> () in
            //            print("audio")
            self?.audioEncoder?.encodeSampleBuffer(sampleBuffer)
        }
        capture.onReady = {
            [weak self] in
            guard let _self = self else {
                return
            }
            
            _self.capture.connectPreView(preview)
            _self.capture.start()
        }
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
    }
    fileprivate func close() {
        self.stopLive()
        self.push.disconnect()
        self.capture?.stop()
    }
}
extension AWLive {
    var videoOrientation : AVCaptureVideoOrientation? {
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
    func rotateWithCurrentOrientation() {
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
    var frontCamera : Bool {
        set {
            self.capture.frontCammera = newValue
            self.rotateWithCurrentOrientation()
        }
        get {
            return self.capture.frontCammera
        }
    }
    var mirror : Bool? {
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
    /// 开始直播，指定当前的旋转位置, 只有开始直播的时候才进行编码
    func startLive() {
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
    }
    func stopLive() {
        self.push?.stop()
        self.videoEncoder?.close()
        self.videoEncoder = nil
        self.audioEncoder = nil
    }
}
extension AWLive : AWLivePushDeletate {
    func push(_ push: AWLivePush2, connectedStateChanged state: AWLiveConnectState) {
        NSLog("push connect changed:\(state)")
    }
    func pushLiveChanged(_ push: AWLivePush2) {
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
