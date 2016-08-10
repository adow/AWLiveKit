//
//  AWLivePush.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 16/8/9.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

import UIKit
import AVFoundation
import VideoToolbox
import AudioToolbox

enum AWLivePushFrameType:Int {
    case SLICE = 0, SLICE_DPA, SLICE_DPB,SLICE_DPC, SLICE_IDR, SLICE_SEI, SLICE_SPS,SLICE_PPS,AUD, FILLER,UNKNOWN
    init(first_bit:UInt8) {
        switch first_bit & 0x1f {
        case 1:
            self =  .SLICE
        case 2:
            self = .SLICE_DPA
        case 3:
            self = .SLICE_DPB
        case 4:
            self = .SLICE_DPC
        case 5:
            self = .SLICE_IDR
        case 6:
            self = .SLICE_SEI
        case 7:
            self = .SLICE_SPS
        case 8:
            self = .SLICE_PPS
        case 9:
            self = .AUD
        case 12:
            self = .FILLER
        default:
            self = .UNKNOWN
        }
    }
    var name : String {
        switch self {
        case .SLICE:
            return "SLICE"
        case .SLICE_DPA:
            return "SLICE_DPA"
        case .SLICE_DPB:
            return "SLICE_DPB"
        case .SLICE_DPC:
            return "SLICE_DPC"
        case .SLICE_IDR:
            return "SLICE_IDR"
        case .SLICE_SEI:
            return "SLICE_SEI"
        case .SLICE_SPS:
            return "SLICE_SPS"
        case .SLICE_PPS:
            return "SLICE_PPS"
        case .AUD:
            return "AUD"
        case .FILLER:
            return "FILLER"
        case .UNKNOWN:
            return "UNKNOWN"
        }
    }
    
}

class AWLivePush: NSObject {
   var rtmpQueue : dispatch_queue_t = dispatch_queue_create("adow.rtmp", DISPATCH_QUEUE_SERIAL)
    var sps_pps_sended : Bool = false
    let avvc_header_length : size_t = 4
    var startTime : NSDate = NSDate()
    init(url:String) {
        super.init()
        if aw_rtmp_connection(url) == 1 {
            NSLog("rtmp connected")
        }
        else {
            NSLog("rtmp connect failed")
        }
        
    }
    

}
extension AWLivePush {
    /// 推送视频
    func pushVideoSampleBuffer(sampleBuffer:CMSampleBuffer) {
        dispatch_async(self.rtmpQueue) { 
            self._go_pushVideoSampleBuffer(sampleBuffer)
        }
    }
    /// 推送视频内容
    private func _go_pushVideoSampleBuffer(sampleBuffer:CMSampleBuffer) {
        guard sampleBuffer.isDataReady else {
            NSLog("Video Data is not ready")
            return
        }
        guard let keyFrame = sampleBuffer.isKeyFrame else {
            NSLog("Video Key Frame is empty")
            return
        }
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            NSLog("Video Data Buffer is empty")
            return
        }
        /// sps, pps
        if keyFrame && !self.sps_pps_sended {
            guard let sps_data = sampleBuffer.sps_data, pps_data = sampleBuffer.pps_data else {
                NSLog("Video sps or pps is nil")
                return
            }
            self.sps_pps_sended = true
            aw_rtmp_send_sps_pps(UnsafeMutablePointer<UInt8>(sps_data.bytes),
                                 Int32(sps_data.length),
                                 UnsafeMutablePointer<UInt8>(pps_data.bytes),
                                 Int32(pps_data.length))
        }
        /// data
        var totalLength :size_t = 0
        var dataPointer : UnsafeMutablePointer<Int8> = nil
        guard CMBlockBufferGetDataPointer(dataBuffer, 0, nil, &totalLength, &dataPointer) == noErr else {
            NSLog("Could not get dataPointer")
            return
        }
        let dataPointer_u = UnsafeMutablePointer<UInt8>(dataPointer)
        var bufferOffset : size_t = 0
        while bufferOffset < totalLength - avvc_header_length {
            var nal_unit_length : UInt32 = 0
            memcpy(&nal_unit_length, dataPointer_u + bufferOffset, avvc_header_length)
            nal_unit_length = CFSwapInt32BigToHost(nal_unit_length)
            
//            let data_frame = NSData(bytes: dataPointer_u + bufferOffset + avvc_header_length, length: Int(nal_unit_length))
//            debugPrint("frame:\(keyFrame)")
//            debugPrint(data_frame)
            let first_bit = (dataPointer_u + bufferOffset + avvc_header_length).memory
            let frame_type = AWLivePushFrameType(first_bit: first_bit)
//            let idr_frame = (first_bit & 0x1f) == 5
            let idr_frame = frame_type == .SLICE_IDR
//            print("frame type:\(frame_type),\(first_bit),\(first_bit & 0x1f),timeStamp:\(nTimeStamp)")
            
            let timeOffset = abs(self.startTime.timeIntervalSinceNow) * 1000
            aw_rtmp_send_h264_video(
                dataPointer_u + bufferOffset + avvc_header_length,
                UInt32(nal_unit_length),
                idr_frame ? 1 : 0,
                UInt32(timeOffset))
            
            bufferOffset = bufferOffset + avvc_header_length + Int(nal_unit_length)
//            nTimeStamp += (1000 / 30)
        }
    }
}
