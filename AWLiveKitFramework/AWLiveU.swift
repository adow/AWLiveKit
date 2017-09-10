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

/// App 版本号
fileprivate func app_info(forClass aClass:AnyClass? = nil) -> (app_name:String, app_id: String, version:String,build:String) {
    let info = aClass == nil ? Bundle.main.infoDictionary : Bundle(for: aClass!).infoDictionary
    let version = (info?["CFBundleShortVersionString"] as? String) ?? ""
    let build = (info?["CFBundleVersion"] as? String) ?? ""
    let app_name = (info?["CFBundleName"] as? String) ?? ""
    let app_id = (info?["CFBundleIdentifier"] as? String) ?? ""
    return (app_name:app_name,app_id:app_id, version:version, build:build)
}
// MARK: - AWLiveBase
public class AWLiveBase {
    public var push : AWLivePushC!
    public var videoQuality : AWLiveCaptureVideoQuality!
    public var orientation : AVCaptureVideoOrientation!
    public var url : String!
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
        debugPrint("AWLiveKit:\(AWLiveBase.version)")
        ///
        self.videoQuality = videoQuality
        self.orientation = orientation
        self.url = url
        /// push
        push = AWLivePushC(url: url)
        push.delegate = self
        push.connectURL()
        
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
        /// 关闭连接
        self.push?.disconnect()
        /// 关闭采集和编码
        self.stopCapture()
        NotificationCenter.default.removeObserver(self)
        debugPrint("AWLiveBase release")
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
        self.startVideoEncoder()
    }
    public func stopCapture() {
        self.stopVideoEncoder()
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
    public class var version :String {
        let (_,_,live_version, live_build) = app_info(forClass: AWLiveBase.self)
        return "\(live_version)/\(live_build)"
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
        /// 还未连接，连接好之后再开始推流
        guard self.isConnected else {
            self.push?.connectURL(completionBlock: { 
                [weak self] in
                /// 开始推流
                self?.push?.start()
                /// 开始状态数据检测
                self?.liveStat?.start()
            })
            return
        }
        /// 已经连接的话，直接开始推流
        /// 开始推流
        self.push?.start()
        /// 开始状态数据检测
        self.liveStat?.start()   
    }
    public func stopLive() {
        /// 结束推流
        self.push?.stop()
        /// 断开连接
        self.push?.disconnect()
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
        debugPrint("ret:\(ret)")
    }
    func stopVideoEncoder() {
        aw_video_encoder_close()
    }
}
extension AWLiveBase:AWLivePushDeletate {
    public func push(_ push: AWLivePushC, connectedStateChanged state: AWLiveConnectState) {
        debugPrint("push connect changed:\(state)")
    }
    public func pushLiveChanged(_ push: AWLivePushC) {
        debugPrint("push live changed:\(push.isLive)")
    }
    public func pushError(_ code: Int, withMessage message: String) {
        
    }
    public func resetPushError() {
        
    }
}
extension AWLiveBase {
    @objc fileprivate func onNotificationEnterForeground(_ notification:Notification) {
        self.startCapture()
        if self.isInterruption {
            self.isInterruption = false
            self.startLive()
        }
    }
    @objc fileprivate func onNotificationResign(_ notification:Notification) {
        self.stopCapture()
        /// 如果正在直播，那标记未打断，回到界面的时候，将直接开始直播
        if let _isLive = self.isLive , _isLive{
            self.stopLive()
            self.isInterruption = true
        }
    }
    @objc fileprivate func onNotificationTerminate(_ notification:Notification) {
        self.stopCapture()
        self.stopLive()
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
            debugPrint("AVLiveCapture failed")
            return nil
        }
        ///
        capture.onVideoSampleBuffer = {
            [weak self](sampleBuffer) -> () in
            /// 只有在推流开始的时候才进行编码
            guard let _self = self else {
                return
            }
//            let timeStamp = sampleBuffer.presentationTimeStamp
//            let duration = sampleBuffer.duration
//            debugPrint("video encoding: timeStamp \(CMTimeGetSeconds(timeStamp)),duration \(CMTimeGetSeconds(duration))")
            let ret = aw_video_encode_samplebuffer(sampleBuffer, { (sample_buffer_encoded, context) in
                if let sp = sample_buffer_encoded {
                    //debugPrint("video encoded:\(sp)")
                    let timeStamp = sp.presentationTimeStamp
//                    let duration = sp.duration
//                    debugPrint("video encoded:\(CMTimeGetSeconds(timeStamp)),\(CMTimeGetSeconds(duration))")
                    let _weak_self = unsafeBitCast(context, to: AWLiveBase.self)
                    let _weak_push = _weak_self.push
                    if let _live = _weak_push?.isLive, _live {
                        _weak_push?.pushVideoSampleBuffer(sp,abs_timeStamp: CMTimeGetSeconds(timeStamp))
                    }
                }
                else {
                    debugPrint("video not encoded")
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
            let timeStamp = sampleBuffer.presentationTimeStamp
//            let duration = sampleBuffer.duration
//            debugPrint("audio encoding: timeStamp \(CMTimeGetSeconds(timeStamp)),duration \(CMTimeGetSeconds(duration))")
            /// 
            let buffer_list = aw_audio_encode(sampleBuffer)
            if let _buffer_list = buffer_list {
                //debugPrint("audio encoded")
                /// push
                if let _live = _self.push?.isLive, _live {
                    /// 进入异步推流队列，一定要在推送完之后在释放他，否则会出现杂音，ssr 解码音频的警告， hls 不同步等现象
                    _self.push?.pushAudioBufferList(_buffer_list, abs_timeStamp:CMTimeGetSeconds(timeStamp))
                }
                else {
                    /// 如果没有推流就直接释放
                    aw_audio_release(_buffer_list)
                }
                _self.liveStat?.audioEncoderError = nil
            }
            else {
                debugPrint("audio not encoded")
                _self.liveStat?.audioEncoderError = "音频编码错误"
            }
            
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
        super.startCapture()
        /// 如果已经准备可以开始，那直接开始捕捉，否则进行一个回调函数，等他准备好了再开始
        guard let _capture = self.capture,!_capture.captureSession.isRunning else {
            return
        }
        if _capture.ready {
            _capture.connectPreView(self.preview)
            _capture.start()
        }
        else {
            _capture.onReady = {
                [weak self] in
                guard let _self = self else {
                    return
                }
                _capture.connectPreView(_self.preview)
                _capture.start()
            }
        }
    }
    override public func stopCapture() {
        super.stopCapture()
        self.capture?.stop()
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
            debugPrint("AWGPUImageCapture failed")
        }
        capture.camera.frameRate = Int32(videoQuality.recommandVideoBiterates.recommandedFPS.fps)
        capture.onAudioSampleBuffer = {
            [weak self] (sampleBuffer) -> () in
            guard let _self = self else {
                return
            }
            //            debugPrint("audio sample buffer")
            let timeStamp = sampleBuffer.presentationTimeStamp
            if let buffer_list = aw_audio_encode(sampleBuffer) {
                //debugPrint("audio buffer list:\(buffer_list)")
                if let _live = _self.push?.isLive, _live {
                    _self.push.pushAudioBufferList(buffer_list, abs_timeStamp: CMTimeGetSeconds(timeStamp))
                }
                else {
                    aw_audio_release(buffer_list)
                }
                _self.liveStat?.audioEncoderError = nil
            }
            else {
                debugPrint("no audio encoded")
                _self.liveStat?.audioEncoderError = "音频编码错误"
            }
            
        }
        capture.onVideoPixelBuffer = {
            [weak self](pixelBuffer, presentation_time, duration) -> () in
            guard let _self = self else {
                return
            }
//            debugPrint("video sample buffer")
            let ret = aw_video_encode_pixelbuffer(pixelBuffer, presentation_time, duration, { (sample_buffer, context) in
                if let _p = sample_buffer {
                    //debugPrint("video sample buffer encoded:\(_p)")
                    let timeStamp = _p.presentationTimeStamp
                    let _weak_push = unsafeBitCast(context, to: AWLivePushC.self)
                    if _weak_push.isLive {
                        _weak_push.pushVideoSampleBuffer(_p, abs_timeStamp: CMTimeGetSeconds(timeStamp))
                    }
                    
                }
                else {
                    debugPrint("no video encoded")
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
        super.startCapture()
        self.capture?.start()
    }
    override public func stopCapture() {
        super.stopCapture()
        self.capture?.stop()
    }
    
}
