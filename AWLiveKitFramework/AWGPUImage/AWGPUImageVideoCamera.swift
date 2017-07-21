//
//  AWGPUImageCamera.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/7/21.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

import Foundation
import GPUImage

public class AWGPUImageVideoCamera : GPUImageVideoCamera {
  
    var onAudioSampleBuffer : AWGPUImageCaptureSampleBufferCallback? = nil
    
    /*
    public override init(sessionPreset:String, cameraPosition: AVCaptureDevicePosition){
        super.init(sessionPreset:sessionPreset, cameraPosition: cameraPosition)
        self.addAudioInputsAndOutputs()
    }
    */
    public override func processAudioSampleBuffer(_ sampleBuffer : CMSampleBuffer) {
        
        super.processAudioSampleBuffer(sampleBuffer)
        self.onAudioSampleBuffer?(sampleBuffer)
    }
    
}
