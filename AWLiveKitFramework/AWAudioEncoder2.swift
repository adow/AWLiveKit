//
//  AWAudioEncoder2.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/7/11.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

import UIKit
import AVFoundation

fileprivate let _shared = AWAudioEncoder2()
public class AWAudioEncoder2: NSObject {
    public var shared : AWAudioEncoder2 {
        return _shared
    }
    public var onEncoded : ((AudioBufferList) -> ())? = nil
    public func encode(_ sampleBuffer : CMSampleBuffer) {
        aw_audio_encode_samplebuffer(sampleBuffer)
    }
}
