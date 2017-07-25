//
//  AWLivePushC.swift
//  AWLiveKit
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
            [.NotConnect:"NotConnect",
             .Connecting : "Connecting",
             .Connected : "Connected"]
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
    public init(url:String) {
        self.rtmpUrl = url
        self.connectURL(url)
    }
    fileprivate func connectURL(_ url:String) {
        rtmp_queue.async {
            guard self.connectState == .NotConnect else {
                return
            }
            self.connectState = .Connecting
            let result = aw_rtmp_connection(url);
            if result == 1 {
                NSLog("Live Push Connected")
                aw_rtmp_send_audio_header()
                NSLog("Audio Header Sent")
                self.start_time = Date()
                self.connectState = .Connected
            }
            else {
                NSLog("RTMP Connect Failed")
                self.connectState = .NotConnect
                /// 3秒后重新连接
                self.reconnect()
                
            }
        }
    }
    /// 关闭 rtmp 连接
    public func disconnect() {
        guard self.connectState == .Connected else {
            return
        }
        aw_rtmp_close()
        self.connectState = .NotConnect
    }
    fileprivate func reconnect() {
        guard self.reconnectTimer == nil else {
            return
        }
        NSLog("Reconnect in 3seconds")
        DispatchQueue.main.async {
            self.reconnectTimer = Timer.scheduledTimer(timeInterval: 3.0,
                                                       target: self,
                                                       selector: #selector(AWLivePushC.onReconnectTimer(sender:)),
                                                       userInfo: nil,
                                                       repeats: false)    
        }
        
    }
    @objc func onReconnectTimer(sender:Timer!) {
        sender.invalidate()
        self.reconnectTimer = nil
        self.connectURL(self.rtmpUrl)
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
    public func pushVideoSampleBuffer(_ sampleBuffer : CMSampleBuffer) {
        rtmp_queue.async {
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
                                       self.timeOffset,
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
    public func pushAudioBufferList(_ audioList : AudioBufferList) {
        rtmp_queue.async {
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
            
            let push_result = aw_push_audio_bufferlist(audioList, self.timeOffset)
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
