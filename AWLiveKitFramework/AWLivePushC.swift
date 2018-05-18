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
    var audio_header_sent : Int32 = 0
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
   
    /// 开始推流时的时间戳
    var startVideoTimeStamp : Double = 0.0
    var startAudioTimeStamp : Double = 0.0
    /// 最近一个推流的时间戳
    var lastVideoTimeStamp : Double = 0.0
    var lastAudioTimeStamp : Double = 0.0
    public init(url:String) {
        self.rtmpUrl = url
//        self.connectURL(url)
    }
    
    public func connectURL(completionBlock completion:(()->())? = nil) {
//        debugPrint("push connect")
        rtmp_queue.sync {
//            debugPrint("run connect")
            guard self.connectState == .NotConnect else {
                return
            }
            self.connectState = .Connecting
            let result = aw_rtmp_connection(self.rtmpUrl!);
            if result == 1 {
                debugPrint("Live Push Connected")
                self.start_time = Date()
                self.connectState = .Connected
                self.isLive = true
                self.sps_pps_sent = 0; /// 重设 sps_pps
                self.audio_header_sent = 0; /// 重新发送 audio header
                completion?()
            }
            else {
                debugPrint("RTMP Connect Failed:\(result)")
                self.connectState = .NotConnect
                aw_rtmp_close()
                /// 3秒后重新连接, 这里不调用 reconnect
//                self.reconnect()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1.5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { () -> Void in
                    self.connectURL(completionBlock: completion)
                }
            }
        }
    }
    /// 关闭 rtmp 连接
    public func disconnect() {
//        debugPrint("push disconnect")
        self.rtmp_queue.sync {
            [weak self] in
//            debugPrint("run disconnect")
            guard let _self = self, _self.connectState == .Connected else {
                debugPrint("not connected")
                return
            }
            _self.isLive = false
            aw_rtmp_close()
            _self.connectState = .NotConnect
        }

    }
    /// 在推流错误时，主动断开，重新连接
    fileprivate func reconnect() {
        self.disconnect()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(3.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { () -> Void in
            self.connectURL()
            
        }
    }

}
extension AWLivePushC {
    fileprivate func counterPushFailed() {
        /// 超过30次发送错误，就断开连接
        self.pushFailedCounter += 1
        debugPrint("push failed:\(self.pushFailedCounter)")
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
//        debugPrint("push video")
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
        rtmp_queue.async {
//            debugPrint("run video")
            if self.startVideoTimeStamp == 0.0 {
                self.startVideoTimeStamp = abs_timeStamp
            }
            let timeStamp = (abs_timeStamp - self.startVideoTimeStamp) * 1000.0
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
                self.lastVideoTimeStamp = timeStamp
                self.resetPushFailed()
                DispatchQueue.main.async {
                    self.delegate?.resetPushError()
                }
            }
        }
    }
    public func pushAudioBufferList(_ audioList : UnsafeMutablePointer<AudioBufferList>, abs_timeStamp : Double) {
//        debugPrint("push audio")
        /// 没有连接的情况下，自动连接
        guard self.connectState == .Connected else {
            aw_audio_release(audioList)
            self.reconnect()
            self.delegate?.pushError(-2, withMessage: "正在重新连接")
            return
        }
        /// 开始直播了才推流
        guard self.isLive else {
            aw_audio_release(audioList)
            self.delegate?.pushError(-1, withMessage: "未开始推流")
            return
        }
        rtmp_queue.async {
//            debugPrint("run audio")
            if self.startAudioTimeStamp == 0.0 {
                self.startAudioTimeStamp = abs_timeStamp
            }
            let timeStamp = (abs_timeStamp - self.startAudioTimeStamp) * 1000.0
            /// 没有连接的情况下，自动连接
            guard self.connectState == .Connected else {
                aw_audio_release(audioList)
                self.reconnect()
                self.delegate?.pushError(-2, withMessage: "正在重新连接")
                return
            }
            /// 开始直播了才推流
            guard self.isLive else {
                aw_audio_release(audioList)
                self.delegate?.pushError(-1, withMessage: "未开始推流")
                return
            }
            
            let push_result = aw_push_audio_bufferlist(audioList.pointee,
                                                        timeStamp,&self.audio_header_sent)
            aw_audio_release(audioList)
            if (push_result != 0) {
                self.counterPushFailed()
                DispatchQueue.main.async {
                    self.delegate?.pushError(Int(push_result), withMessage: "音频推流失败")
                }
            }
            else {
                self.lastAudioTimeStamp = timeStamp
                self.resetPushFailed()
                DispatchQueue.main.async {
                    self.delegate?.resetPushError()
                }
            }
        }
    }
    
}
