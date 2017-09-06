//
//  AWLivePushC.swift
//  AWLiveKit
//  
//  调用的 aw_live_push, C 实现, Swift 封装
//
//  Created by 秦 道平 on 2016/12/29.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

import Foundation
import AVFoundation
import VideoToolbox
import AudioToolbox

public enum AWLiveConnectState : Int ,CustomStringConvertible{
    case NotConnect = 0, Connecting = 1, Connected = 2
    
    public var description: String {
        let d : [AWLiveConnectState:String] =
            [.NotConnect:"未连接",
             .Connecting : "正在连接",
             .Connected : "已连接"]
        return d[self] ?? "Unknown"
    }
}
public protocol AWLivePushDeletate : class{
    /// 连接状态改变
    func push(_ push:AWLivePushC, connectedStateChanged state:AWLiveConnectState)
    /// 播出状态改变
    func pushLiveChanged(_ push:AWLivePushC)
    /// 发生错误时通知外部
    func pushError(_ code:Int, withMessage message:String)
    /// 充值错误状态
    func resetPushError()
}
public class AWLivePushC {
    var rtmp_queue : DispatchQueue = DispatchQueue(label: "adow.rtmp", attributes: [])
    var sps_pps_sent : Int32 = 0
    let avvc_header_length : size_t = 4
    var start_time : Date? = nil
    
    /// 累计 push 出错的次数
    fileprivate var pushFailedCounter : Int = 0
    var rtmpUrl : String!
    var reconnectTimer : Timer?
    public weak var delegate : AWLivePushDeletate? = nil
    public var connectState : AWLiveConnectState = .NotConnect {
        didSet {
            DispatchQueue.main.async {
                self.delegate?.push(self, connectedStateChanged: self.connectState)
            }
        }
    }
    /// 播出
    public var isLive : Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.delegate?.pushLiveChanged(self)
            }
        }
    }
    var videoTimeStamp : Double = 0.0;
    var audioTimeStamp : Double = 0.0;
    public init(url:String) {
        self.rtmpUrl = url
//        self.connectURL(url)
    }
    fileprivate func prepareFlvFile() {
        let flv_filename = cache_dir.appending("/record.flv")
        let flv_filename_url = URL(fileURLWithPath: flv_filename)
        if FileManager.default.fileExists(atPath: flv_filename_url.path) {
            do {
                try FileManager.default.removeItem(atPath: flv_filename_url.path)
                NSLog("remove record:\(flv_filename_url.path)")
            }
            catch {
                NSLog("remove record failed")
            }
        }
//        aw_push_flv_file_open(flv_filename_url.path)
        NSLog("open recoard file:\(flv_filename_url.path)")
    }
    public func connectURL(completionBlock completion:(()->())? = nil) {
        rtmp_queue.async {
            guard self.connectState == .NotConnect else {
                return
            }
            self.connectState = .Connecting
            let result = aw_rtmp_connection(self.rtmpUrl);
            if result == 1 {
                NSLog("Live Push Connected")
//                aw_rtmp_send_audio_header()
//                NSLog("Audio Header Sent")
                self.start_time = Date()
                self.connectState = .Connected
                completion?()
            }
            else {
                NSLog("RTMP Connect Failed:\(result)")
                self.connectState = .NotConnect
                aw_rtmp_close()
                /// 3秒后重新连接, 这里不调用 reconnect
//                self.reconnect()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(3.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { () -> Void in
                    self.connectURL(completionBlock: completion)
                }
            }
        }
    }
    /// 关闭 rtmp 连接
    public func disconnect() {
        guard self.connectState == .Connected else {
            return
        }
        /// 延时一秒关闭连接，因为 rtmp_queue 中还有内容没有发送，他的运行会导致出错，rtmp_queue 也没有取消功能
//        self.rtmp_queue.suspend()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { [weak self]() -> Void in
            aw_rtmp_close()
            self?.connectState = .NotConnect
        }
        
    }
//    fileprivate func reconnect() {
//        guard self.reconnectTimer == nil else {
//            return
//        }
//        NSLog("Reconnect in 3seconds")
//        DispatchQueue.main.async {
//            self.reconnectTimer = Timer.scheduledTimer(timeInterval: 3.0,
//                                                       target: self,
//                                                       selector: #selector(AWLivePushC.onReconnectTimer(sender:)),
//                                                       userInfo: nil,
//                                                       repeats: false)    
//        }
//        
//    }
//    @objc func onReconnectTimer(sender:Timer!) {
//        sender.invalidate()
//        self.reconnectTimer = nil
//        self.disconnect()
//        self.connectURL()
//    }
    /// 在推流错误时，主动断开，重新连接
    fileprivate func reconnect() {
        self.disconnect()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(3.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { () -> Void in
            self.connectURL()
            
        }
    }
    /// 开始推流
    public func start() {
        self.isLive = true
    }
    /// 结束推流
    public func stop() {
        self.isLive = false
    }
}
extension AWLivePushC {
    fileprivate func counterPushFailed() {
        /// 超过30次发送错误，就断开连接
        self.pushFailedCounter += 1
        NSLog("push failed:\(self.pushFailedCounter)")
        if (self.pushFailedCounter >= 30) {
            self.disconnect()
        }
        
    }
    fileprivate func resetPushFailed() {
        self.pushFailedCounter = 0
    }
    public var timeOffset : Double {
        return abs(self.start_time?.timeIntervalSinceNow ?? 0.0) * 1000;
    }
    public func pushVideoSampleBuffer(_ sampleBuffer : CMSampleBuffer, abs_timeStamp : Double) {
        rtmp_queue.async {
            if self.videoTimeStamp == 0.0 {
                self.videoTimeStamp = abs_timeStamp
            }
            let timeStamp = (abs_timeStamp - self.videoTimeStamp) * 1000.0
            /// 没有连接的情况下，自动连接
            guard self.connectState == .Connected else {
                self.reconnect()
                self.delegate?.pushError(-2, withMessage: "正在重新连接")
                return
            }
            /// 开始直播了才推流
            guard self.isLive else {
                self.delegate?.pushError(-1, withMessage: "未开始推流")
                return
            }
            
            let push_result = aw_push_video_samplebuffer(sampleBuffer,
                                        timeStamp,
                                       &self.sps_pps_sent)
            if (push_result != 0) {
                self.counterPushFailed()
                DispatchQueue.main.async {
                    self.delegate?.pushError(Int(push_result), withMessage: "视频推流失败")
                }
            }
            else {
                self.resetPushFailed()
                DispatchQueue.main.async {
                    self.delegate?.resetPushError()
                }
            }
        }
    }
    public func pushAudioBufferList(_ audioList : UnsafeMutablePointer<AudioBufferList>, abs_timeStamp : Double) {
        rtmp_queue.async {
            if self.audioTimeStamp == 0.0 {
                self.audioTimeStamp = abs_timeStamp
            }
            let timeStamp = (abs_timeStamp - self.audioTimeStamp) * 1000.0
            /// 没有连接的情况下，自动连接
            guard self.connectState == .Connected else {
                self.reconnect()
                self.delegate?.pushError(-2, withMessage: "正在重新连接")
                return
            }
            /// 开始直播了才推流
            guard self.isLive else {
                self.delegate?.pushError(-1, withMessage: "未开始推流")
                return
            }
            
            let push_result = aw_push_audio_bufferlist(audioList.pointee,
                                                        timeStamp
                                                        )
            aw_audio_release(audioList)
            if (push_result != 0) {
                self.counterPushFailed()
                DispatchQueue.main.async {
                    self.delegate?.pushError(Int(push_result), withMessage: "音频推流失败")
                }
            }
            else {
                self.resetPushFailed()
                DispatchQueue.main.async {
                    self.delegate?.resetPushError()
                }
            }
        }
    }
    
}
