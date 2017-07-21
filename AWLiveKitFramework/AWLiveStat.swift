//
//  AWLiveStat.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/2/12.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
public protocol AWLiveStatDelegate : class{
    func updateLiveStat(stat:AWLiveStat)
}

public class AWLiveStat {
    fileprivate var timer : Timer!
    fileprivate var startTime : Date = Date()
    var nowTimeStr : String = "-"
    var liveTimeStr : String = "-"
    /// 本地打开后的流量统计
    fileprivate var networkTotal : Int64! = 0
    /// 系统内的流量统计
    fileprivate var networkTotalSystem : Int64! = 0
    /// 直播中输出的网络流量
    public var networkCostsMB : Float = 0.0
    public var networkCostsMB_str : String = "-"
    /// 输出的网速
    public var networkSpeedKB : Int = 0
    public var networkSpeedKB_str = "-"
    /// 网络信号强度
    public var networkSignalStrgenth : String = "-"
    /// 从开始到现在的时间
    public var secondsFromStart : Double {
        return abs(startTime.timeIntervalSinceNow)
    }
    /// 上一次计数器更新时间
    var lastUpdateTime : Date = Date()
    /// 上一次更新到现在的时间
    var secondsFromLastUpdate : Double {
        return abs(lastUpdateTime.timeIntervalSinceNow)
    }
    /// 上一次更新电池的时间
    var lastUpdateBatteryTime : Date = Date()
    /// 电池
    public var battery : Int?
    /// 当前麦克风
    public var microphone : String = ""
    /// 视频编码器出错信息
    public var videoEncoderError : String? = nil
    /// 音频编码器出错信息
    public var audioEncoderError : String? = nil
    /// 推流出错信息
    public var pushError : String? = nil
    /// 计时器更新后回调
    public weak var delegate : AWLiveStatDelegate? = nil
    public init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onNotificationRouteChange(_:)),
                                               name: NSNotification.Name.AVAudioSessionRouteChange,
                                               object: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.stop()
    }
    public func start() {
        self.startTime = Date()
        self.networkTotal = 0
        self.networkTotalSystem = 0
        self.networkCostsMB = 0
        self.networkCostsMB_str = "-"
        self.networkSpeedKB = 0
        self.networkSpeedKB_str = "-"
        self.networkSignalStrgenth = "-"
        self.lastUpdateTime = Date()
        self.lastUpdateBatteryTime = Date()
        self.battery = nil
        timer = Timer.scheduledTimer(timeInterval: 1.0,
                                     target: self,
                                     selector: #selector(onTimer(sender:)),
                                     userInfo: nil,
                                     repeats: true)
    }
    public func stop() {
        self.timer?.invalidate()
    }
    @objc fileprivate func onTimer(sender:Timer!) {
        self.updateLiveTime()
        self.updateNetwork()
        self.updateBattery()
        self.lastUpdateTime = Date()
        self.delegate?.updateLiveStat(stat: self)
    }
    /// 输出
    public var outputDescription : String {
        var error_msg = ""
        if let _error = self.videoEncoderError {
            error_msg += "\(_error)\n"
        }
        if let _error = self.audioEncoderError {
            error_msg += "\(_error)\n"
        }
        if let _error = self.pushError {
            error_msg += "\(_error)\n"
        }
        
        return "\(self.liveTimeStr) 播出\n \(self.nowTimeStr) 时间\n \(self.networkCostsMB_str) 流量\n \(self.networkSpeedKB_str) 网速\n \(self.battery ?? 0)% 电池\n \(self.networkSignalStrgenth) 网络\n \(self.microphone)\n \(error_msg)\n"
    }
}
extension AWLiveStat {
    fileprivate func updateLiveTime() {
        let div_hours = lldiv(Int64(self.secondsFromStart), 3600)
        let live_hours = div_hours.quot
        let div_minutes = lldiv(div_hours.rem, 60)
        let live_minutes = div_minutes.quot
        let live_seconds = div_minutes.rem
        let str_live_hours = String(format: "%02d", live_hours)
        let str_live_minutes = String(format: "%02d", live_minutes)
        let str_live_seconds = String(format: "%02d", live_seconds)
        self.liveTimeStr =  "\(str_live_hours):\(str_live_minutes):\(str_live_seconds)"
        
        let date_formatter = DateFormatter()
        date_formatter.dateFormat = "HH':'mm':'ss"
        let sys_time_str = date_formatter.string(from: Date())
        self.nowTimeStr = sys_time_str
    }
    fileprivate func updateNetwork() {
        let bytes = get_interface_bytes()
        if self.networkTotalSystem == 0 {
            self.networkTotalSystem = bytes
        }
        let append_bytes = max(bytes - self.networkTotalSystem, 0)
        /// 整个总流量
        self.networkTotalSystem = bytes
        /// 播出中使用的流量
        self.networkTotal! += append_bytes
//        debugPrint("networkTotal:\(self.networkTotal ?? 0),append_bytes:\(append_bytes),system:\(networkTotalSystem ?? 0)")
        /// 显示流量
        self.networkCostsMB = Float(networkTotal) / 1000.0 / 1000.0
        self.networkCostsMB_str =  String(format: "%.1f MB", self.networkCostsMB)
        /// 显示网速
        let networkSpeed = Int64((self.secondsFromLastUpdate != 0.0) ?
                            Double(append_bytes) / self.secondsFromLastUpdate : 0.0)
        self.networkSpeedKB = Int(networkSpeed) / 1000
        if self.networkSpeedKB > 80 {
            self.networkSpeedKB_str = "\(networkSpeedKB) KB/s"
        }
        else {
            self.networkSpeedKB_str = "🚀网速过低 \(networkSpeedKB) KB/s"
        }
        /// signalStrength
        self.networkSignalStrgenth = NetworkHelper.signalStrength() ?? "-"
    }
    fileprivate func updateBattery() {
        guard abs(self.lastUpdateBatteryTime.timeIntervalSinceNow) >= 10 else {
            return
        }
        self.lastUpdateBatteryTime = Date()
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        self.battery = Int(device.batteryLevel * 100.0)
        device.isBatteryMonitoringEnabled = false
        NSLog("battery:\(self.battery ?? 0)")
    }
    @objc func onNotificationRouteChange(_ notification:Notification) {
        let inputs = AVAudioSession.sharedInstance().currentRoute.inputs
        for one_input in inputs {
            NSLog("input:\(one_input.portName),\(one_input.portType)")
            self.microphone = "\(one_input.portName)\n\(one_input.portType)"
        }
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        for one_output in outputs {
            NSLog("output:\(one_output.portName),\(one_output.portType)")
        }
    }
    
}
