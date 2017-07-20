//
//  AWLiveG.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/7/20.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

public class AWLiveG {
    public var push : AWLivePushC!
    public var capture : AWGPUImageCapture!
    public weak var preview : GPUImageView!
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
                 onPreview preview : GPUImageView,
                 withQuality videoQuality : AWLiveCaptureVideoQuality = AWLiveCaptureVideoQuality._720,
                 atOrientation orientation : AVCaptureVideoOrientation = .portrait) {
        self.videoQuality = videoQuality
        self.preview = preview
       
        /// 视频编码器
        let video_size = videoQuality.videoSizeForOrientation(orientation)
        let ret = aw_video_encoder_init(Int32(video_size.width),
                Int32(video_size.height),
                Int32(videoQuality.recommandVideoBiterates.bitrates),
            Int32(videoQuality.recommandVideoBiterates.recommandedFPS.fps),
                videoQuality.recommandVideoBiterates.recommandedProfile.profile)
        NSLog("ret:\(ret)")
        /// push
        push = AWLivePushC(url: url)
        push.delegate = self
        capture =
            AWGPUImageCapture(sessionPreset: videoQuality.sessionPreset,
                              orientation: UIInterfaceOrientation(rawValue:orientation.rawValue)!,
                                    preview: self.preview!)
        capture.onAudioSampleBuffer = {
            [weak self] (sampleBuffer) -> () in
            guard let _self = self,let _push = _self.push, _push.isLive else {
                return
            }
            //            NSLog("audio sample buffer")
            if let buffer_list = aw_audio_encode(sampleBuffer) {
                NSLog("audio buffer list:\(buffer_list)")
                _self.push.pushAudioBufferList(buffer_list.pointee)
                aw_audio_release(buffer_list)
            }
            else {
                NSLog("no audio encoded")
            }
            
        }
        capture.onVideoPixelBuffer = {
            [weak self](pixelBuffer, presentation_time, duration) -> () in
            guard let _self = self,let _push = _self.push, _push.isLive else {
                return
            }
//            NSLog("video sample buffer")
            aw_video_encode_pixelbuffer(pixelBuffer, presentation_time, duration, { (sample_buffer, context) in
                if let _p = sample_buffer {
//                    NSLog("video sample buffer encoded:\(_p)")
                    NSLog("video sample buffer encoded")
                    let _weak_push = unsafeBitCast(context, to: AWLivePushC.self)
                    _weak_push.pushVideoSampleBuffer(_p)
                }
                else {
                    NSLog("no video encoded")
                }
                
            }, unsafeBitCast(_self.push, to: UnsafeMutableRawPointer.self))
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
extension AWLiveG {
    public func switchCamera() {
        self.capture?.camera?.rotateCamera()
    }
}
extension AWLiveG {
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
extension AWLiveG {
    /// 开始直播，指定当前的旋转位置, 只有开始直播的时候才进行编码
    public func startLive() {
        /// 开始推流
        self.push?.start()
        /// 开始状态数据检测
        self.liveStat?.start()
    }
    public func stopLive() {
        /// 结束推流
        self.push?.stop()
        /// 停止状态数据检测
        self.liveStat?.stop()
    }
}
extension AWLiveG:AWLivePushDeletate {
    public func push(_ push: AWLivePushC, connectedStateChanged state: AWLiveConnectState) {
        NSLog("push connect changed:\(state)")
    }
    public func pushLiveChanged(_ push: AWLivePushC) {
        NSLog("push live changed:\(push.isLive)")
    }
}
extension AWLiveG {
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
