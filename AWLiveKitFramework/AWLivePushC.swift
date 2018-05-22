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
    case NotConnect = 0,
        Connecting = 1,
        Connected = 2,
        Released = 3 /// 用来标记连接已经释放了
    
    public var description: String {
        let d : [AWLiveConnectState:String] =
            [.NotConnect:"未连接",
             .Connecting : "正在连接",
             .Connected : "已连接",
             .Released : "已释放"]
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
  
    public enum ConnectResult : Int {
        case Succeed = 0 , Ignored = 1, Failed = 2
    }
    
    /// 同步连接, 失败不会重新连接
    @discardableResult public func connectURLSync() -> ConnectResult{
        guard self.connectState == .NotConnect else {
            return .Ignored
        }
        self.connectState = .Connecting
        
        let result = aw_rtmp_connection(self.rtmpUrl!);
        /// 连接完成就重置错误计数，不管有没有连接成功
        self.pushFailedCounter = 0
        if result == 1 {
            debugPrint("Live Push Connected:",self.rtmpUrl ?? "")
            self.start_time = Date()
            self.connectState = .Connected
            self.isLive = true
            self.sps_pps_sent = 0; /// 重设 sps_pps
            self.audio_header_sent = 0; /// 重新发送 audio header
            return .Succeed
        }
        else {
            return .Failed
        }
    }
    
    /// 异步连接，连接失败就重新连接
    public func connectURL(completionBlock completion:(()->())? = nil) {
//        debugPrint("push connect")
        rtmp_queue.async {
            [weak self] in
            guard let _self = self else {
                return
            }
            let result = _self.connectURLSync()
            if result == .Succeed {
                completion?()
            }
            else if result == .Ignored {
                
            }
            else if result == .Failed {
                /// 开始重连
                self?.reconnect()
            }

        }
    }
  
    /// 同步的断开连接方法
    private func disconnectSync() {
        if self.connectState == .Connected {
            self.isLive = false
            aw_rtmp_close()
        }
        self.connectState = .NotConnect
    }
    
    /// 异步关闭 rtmp 连接
    public func disconnect(completionBlock:(()->())? = nil) {
//        debugPrint("push disconnect")
        self.rtmp_queue.async {
            [weak self] in
//            debugPrint("run disconnect")
            self?.disconnectSync()
            completionBlock?()
        }

    }
    
    /// 同步重连，两个方法都不等待，这个方法应该在异步的 reconnect 中调用
    fileprivate func reconnect() {
        self.rtmp_queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(3.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {[weak self] () -> Void in
            guard let _self = self else {
                return
            }
            _self.disconnectSync()
            let result = _self.connectURLSync()
            if result == .Failed {
                _self.reconnect()
            }
        }
    }
    fileprivate func counterPushFailed() {
        /// 累计30次发送错误，就断开连接
        self.pushFailedCounter += 1
        debugPrint("push failed:\(self.pushFailedCounter)")
        if (self.pushFailedCounter == 30) {
            self.reconnect()
        }

    }

    deinit {
        self.connectState = .Released
        debugPrint("AWLivePushC Released")
        
    }

}
extension AWLivePushC {
    public var timeOffset : Double {
        return abs(self.start_time?.timeIntervalSinceNow ?? 0.0) * 1000;
    }
    
    /// 当连接断开的时候，不做后续处理，直接结束；当发送错误超过30次的时候，就重新连接
    public func pushVideoSampleBuffer(_ sampleBuffer : CMSampleBuffer, abs_timeStamp : Double) {
//        debugPrint("push video")
        rtmp_queue.async {
            if self.startVideoTimeStamp == 0.0 {
                self.startVideoTimeStamp = abs_timeStamp
            }
            let timeStamp = (abs_timeStamp - self.startVideoTimeStamp) * 1000.0
            guard self.connectState == .Connected else {
                self.delegate?.pushError(-2, withMessage: "未连接")
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
                DispatchQueue.main.async {
                    self.delegate?.resetPushError()
                }
            }
        }
    }
    public func pushAudioBufferList(_ audioList : UnsafeMutablePointer<AudioBufferList>, abs_timeStamp : Double) {
//        debugPrint("push audio")
        rtmp_queue.async {
            if self.startAudioTimeStamp == 0.0 {
                self.startAudioTimeStamp = abs_timeStamp
            }
            let timeStamp = (abs_timeStamp - self.startAudioTimeStamp) * 1000.0
            guard self.connectState == .Connected else {
                aw_audio_release(audioList)
                self.delegate?.pushError(-2, withMessage: "未连接")
                return
            }
            /// 开始直播了才推流
            guard self.isLive else {
                aw_audio_release(audioList)
                self.delegate?.pushError(-1, withMessage: "未开始推流")
                return
            }
            
            let push_result = aw_push_audio_bufferlist(audioList.pointee, timeStamp,&self.audio_header_sent)
            aw_audio_release(audioList)
            if (push_result != 0) {
                self.counterPushFailed()
                DispatchQueue.main.async {
                    self.delegate?.pushError(Int(push_result), withMessage: "音频推流失败")
                }
            }
            else {
                self.lastAudioTimeStamp = timeStamp
                DispatchQueue.main.async {
                    self.delegate?.resetPushError()
                }
            }
        }
    }
}
