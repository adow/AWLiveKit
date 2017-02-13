//
//  AWLiveStat.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/2/12.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

import Foundation
import UIKit
protocol AWLiveStatDelegate : class{
    func updateLiveStat(stat:AWLiveStat)
}

class AWLiveStat {
    fileprivate var timer : Timer!
    fileprivate var startTime : Date = Date()
    var nowTimeStr : String = "-"
    var liveTimeStr : String = "-"
    /// 本地打开后的流量统计
    fileprivate var networkTotal : Int64! = 0
    /// 系统内的流量统计
    fileprivate var networkTotalSystem : Int64! = 0
    /// 直播中输出的网络流量
    var networkCostsMB : Float = 0.0
    var networkCostsMB_str : String = "-"
    /// 输出的网速
    var networkSpeedKB : Int = 0
    var networkSpeedKB_str = "-"
    /// 网络信号强度
    var networkSignalStrgenth : String = "-"
    /// 从开始到现在的时间
    var secondsFromStart : Double {
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
    var battery : Int?
    /// 计时器更新后回调
    weak var delegate : AWLiveStatDelegate? = nil
    init() {
    }
    deinit {
        self.stop()
    }
    func start() {
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
    func stop() {
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
    var outputDescription : String {
        return "\(self.liveTimeStr) 播出\n \(self.nowTimeStr) 时间\n \(self.networkCostsMB_str) 流量\n \(self.networkSpeedKB_str) 网速\n \(self.battery ?? 0)% 电池\n \(self.networkSignalStrgenth) 网络\n"
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
        self.networkSpeedKB_str = "\(networkSpeedKB) KB/s"
        /// signalStrength
        self.networkSignalStrgenth = NetworkHelper.signalStrength() ?? "-"
    }
    fileprivate func updateBattery() {
        guard abs(self.lastUpdateBatteryTime.timeIntervalSince1970) >= 10 else {
            return
        }
        self.lastUpdateBatteryTime = Date()
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        self.battery = Int(device.batteryLevel * 100.0)
        device.isBatteryMonitoringEnabled = false
    }
    
}
