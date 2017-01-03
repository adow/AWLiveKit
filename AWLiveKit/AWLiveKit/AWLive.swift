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
    var live : Bool = false
    init(url:String,
         onPreview preview : AWLivePreview,
         withQuality videoQuality : AWLiveCaptureVideoQuality = AWLiveCaptureVideoQuality._720,
         atOrientation orientation : AVCaptureVideoOrientation = .Portrait) {
        self.preview = preview
        /// push
        push = AWLivePush2(url: url)
        /// capture
        capture = AWLiveCapture(sessionPreset: videoQuality.sessionPreset,
                                orientation: .LandscapeRight)
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
        
        /// videoEncoder
        videoEncoder = AWVideoEncoder(outputSize: videoQuality.videoSizeForOrientation(.LandscapeRight),
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
    }
    deinit {
        self.close()
    }
    func close() {
        self.live = false
        self.videoEncoder?.close()
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
        let device_orientation = UIApplication.sharedApplication().statusBarOrientation
        switch device_orientation {
        case .LandscapeLeft:
            self.videoOrientation = .LandscapeLeft
        case .LandscapeRight:
            self.videoOrientation = .LandscapeRight
        case .Portrait:
            self.videoOrientation = .Portrait
        case .PortraitUpsideDown:
            self.videoOrientation = .PortraitUpsideDown
        default:
            self.videoOrientation = .Portrait
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
    func startLive() {
        self.push?.start()
        self.live = true
    }
    func stopLive() {
        self.push?.stop()
        self.live = false
    }
}
