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

// MARK: Frame
enum AWLivePushFrameType:Int, CustomStringConvertible {
    case slice = 0, slice_DPA, slice_DPB,slice_DPC, slice_IDR, slice_SEI, slice_SPS,slice_PPS,aud, filler,unknown
    init(first_bit:UInt8) {
        switch first_bit & 0x1f {
        case 1:
            self =  .slice
        case 2:
            self = .slice_DPA
        case 3:
            self = .slice_DPB
        case 4:
            self = .slice_DPC
        case 5:
            self = .slice_IDR
        case 6:
            self = .slice_SEI
        case 7:
            self = .slice_SPS
        case 8:
            self = .slice_PPS
        case 9:
            self = .aud
        case 12:
            self = .filler
        default:
            self = .unknown
        }
    }
    var name : String {
        switch self {
        case .slice:
            return "SLICE"
        case .slice_DPA:
            return "SLICE_DPA"
        case .slice_DPB:
            return "SLICE_DPB"
        case .slice_DPC:
            return "SLICE_DPC"
        case .slice_IDR:
            return "SLICE_IDR"
        case .slice_SEI:
            return "SLICE_SEI"
        case .slice_SPS:
            return "SLICE_SPS"
        case .slice_PPS:
            return "SLICE_PPS"
        case .aud:
            return "AUD"
        case .filler:
            return "FILLER"
        case .unknown:
            return "UNKNOWN"
        }
    }
    var description: String {
        return self.name
    }
    
}

// MARK: - Push
class AWLivePush: NSObject {
   var rtmpQueue : DispatchQueue = DispatchQueue(label: "adow.rtmp", attributes: [])
    var sps_pps_sended : Bool = false
    let avvc_header_length : size_t = 4
    var startTime : Date = Date()
    /// 连接是否准备就绪, 必须连接完成，并且发送完音频头之后才算完成
    var ready : Bool = false
    init(url:String) {
        super.init()
//        let start_time = NSDate()
        rtmpQueue.async {
            let result = aw_rtmp_connection(url)
            if result == 1 {
                NSLog("rtmp connected")
                aw_rtmp_send_audio_header()
                NSLog("Send audio header")
                self.ready = true /// 完成以上两步才可以后面操作
            }
            else {
                NSLog("rtmp connect failed")
            }    
        }
//        NSLog("Rtmp Connect duration:\(abs(start_time.timeIntervalSinceNow))")
    }
    

}
// MARK: Video
extension AWLivePush {
    /// 推送视频
    func pushVideoSampleBuffer(_ sampleBuffer:CMSampleBuffer) {
        self.rtmpQueue.async { 
            self._go_pushVideoSampleBuffer(sampleBuffer)
        }
    }
    /// 推送视频内容
    fileprivate func _go_pushVideoSampleBuffer(_ sampleBuffer:CMSampleBuffer) {
        guard self.ready else {
//            NSLog("RTMP is not ready")
            return
        }
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
            guard let sps_data = sampleBuffer.sps_data, let pps_data = sampleBuffer.pps_data else {
                NSLog("Video sps or pps is nil")
                return
            }
            self.sps_pps_sended = true
            aw_rtmp_send_sps_pps(UnsafeMutablePointer<UInt8>(mutating: (sps_data as NSData).bytes.bindMemory(to: UInt8.self, capacity: sps_data.count)),
                                 Int32(sps_data.count),
                                 UnsafeMutablePointer<UInt8>(mutating: (pps_data as NSData).bytes.bindMemory(to: UInt8.self, capacity: pps_data.count)),
                                 Int32(pps_data.count))
        }
        /// data
        var totalLength :size_t = 0
        var dataPointer : UnsafeMutablePointer<Int8>? = nil
        guard CMBlockBufferGetDataPointer(dataBuffer, 0, nil, &totalLength, &dataPointer) == noErr else {
            NSLog("Could not get dataPointer")
            return
        }
        dataPointer!.withMemoryRebound(to:UnsafeMutablePointer<UInt8>.self,capacity: totalLength) {
            (p)  in
            let dataPointer_u = p.pointee
            var bufferOffset : size_t = 0
            while bufferOffset < totalLength - avvc_header_length {
                var nal_unit_length : UInt32 = 0
                memcpy(&nal_unit_length, UnsafeRawPointer(dataPointer_u) + bufferOffset, avvc_header_length)
                nal_unit_length = CFSwapInt32BigToHost(nal_unit_length)
                
                //            let data_frame = NSData(bytes: dataPointer_u + bufferOffset + avvc_header_length, length: Int(nal_unit_length))
                //            debugPrint("frame:\(keyFrame)")
                //            debugPrint(data_frame)
                let first_bit = (dataPointer_u + bufferOffset + avvc_header_length).pointee
                let frame_type = AWLivePushFrameType(first_bit: first_bit)
                let idr_frame = frame_type == .slice_IDR
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
}
// MARK: Audio
extension AWLivePush {
    /// 推送音频内容
    func pushAudioBufferList(_ bufferList: AudioBufferList) {
        self.rtmpQueue.async { 
            self._goto_pushAudioBufferList(bufferList)
        }
    }
    /// 推送音频内容
    fileprivate func _goto_pushAudioBufferList(_ bufferList:AudioBufferList) {
        guard self.ready else {
//            NSLog("RTMP is not ready")
            return
        }
        let audio_data_length = bufferList.mBuffers.mDataByteSize
        let audio_data_bytes = bufferList.mBuffers.mData
        let timeOffset = abs(self.startTime.timeIntervalSinceNow) * 1000
        let p = audio_data_bytes!.assumingMemoryBound(to: UnsafeMutablePointer<UInt8>.self)
        aw_rtmp_send_audio(p.pointee, audio_data_length, UInt32(timeOffset))
    }
}
