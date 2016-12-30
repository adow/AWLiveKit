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
    let start_time : NSDate = NSDate()
    var connected : Bool = false
    init(url:String) {
        self.connectURL(url)
    }
    private func connectURL(url:String) {
        dispatch_async(rtmp_queue) {
            let result = aw_rtmp_connection(url);
            if result == 1 {
                self.connected = true
            }
            else {
                NSLog("RTMP Connect Failed")
            }
        }
    }
}
extension AWLivePush2 {
    func pushVideoSampleBuffer(sampleBuffer : CMSampleBuffer) {
        dispatch_async(rtmp_queue) {
            guard self.connected else {
                return
            }
            let time_offset = abs(self.start_time.timeIntervalSinceNow) * 1000
            aw_push_video_samplebuffer(sampleBuffer, time_offset, &self.sps_pps_sent)
        }
    }
    
}
