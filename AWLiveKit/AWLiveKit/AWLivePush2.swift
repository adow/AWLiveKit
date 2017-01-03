//
//  AWLivePush2.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2016/12/29.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

import Foundation
import AVFoundation
import VideoToolbox
import AudioToolbox

class AWLivePush2 {
    var rtmp_queue : dispatch_queue_t = dispatch_queue_create("adow.rtmp", DISPATCH_QUEUE_SERIAL)
    var sps_pps_sent : Int32 = 0
    let avvc_header_length : size_t = 4
    var start_time : NSDate? = nil
    var connected : Bool = false
    /// 播出
    var live : Bool = false
    init(url:String) {
        self.connectURL(url)
    }
    private func connectURL(url:String) {
        dispatch_async(rtmp_queue) {
            let result = aw_rtmp_connection(url);
            if result == 1 {
                NSLog("Live Push Connected")
                aw_rtmp_send_audio_header()
                NSLog("Audio Header Sent")
                self.start_time = NSDate()
                self.connected = true
            }
            else {
                NSLog("RTMP Connect Failed")
            }
        }
    }
    func start() {
        self.live = true
    }
    func stop() {
        self.live = false
    }
}
extension AWLivePush2 {
    var timeOffset : Double {
        return abs(self.start_time?.timeIntervalSinceNow ?? 0.0) * 1000;
    }
    func pushVideoSampleBuffer(sampleBuffer : CMSampleBuffer) {
        dispatch_async(rtmp_queue) {
            guard self.connected && self.live else {
                return
            }
            aw_push_video_samplebuffer(sampleBuffer,
                                       self.timeOffset,
                                       &self.sps_pps_sent)
        }
    }
    func pushAudioBufferList(audioList : AudioBufferList) {
        dispatch_async(rtmp_queue) { 
            guard self.connected && self.live else {
                return
            }
            aw_push_audio_bufferlist(audioList, self.timeOffset)
        }
    }
    
}
