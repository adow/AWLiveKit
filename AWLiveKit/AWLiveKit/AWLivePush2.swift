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
    var rtmp_queue : DispatchQueue = DispatchQueue(label: "adow.rtmp", attributes: [])
    var sps_pps_sent : Int32 = 0
    let avvc_header_length : size_t = 4
    var start_time : Date? = nil
    var connected : Bool = false
    /// 播出
    var live : Bool = false
    init(url:String) {
        self.connectURL(url)
    }
    fileprivate func connectURL(_ url:String) {
        rtmp_queue.async {
            let result = aw_rtmp_connection(url);
            if result == 1 {
                NSLog("Live Push Connected")
                aw_rtmp_send_audio_header()
                NSLog("Audio Header Sent")
                self.start_time = Date()
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
    func pushVideoSampleBuffer(_ sampleBuffer : CMSampleBuffer) {
        rtmp_queue.async {
            guard self.connected && self.live else {
                return
            }
            aw_push_video_samplebuffer(sampleBuffer,
                                       self.timeOffset,
                                       &self.sps_pps_sent)
        }
    }
    func pushAudioBufferList(_ audioList : AudioBufferList) {
        rtmp_queue.async { 
            guard self.connected && self.live else {
                return
            }
            aw_push_audio_bufferlist(audioList, self.timeOffset)
        }
    }
    
}
