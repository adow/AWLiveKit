//
//  GPUImageOutputA.swift
//  TestGPUImage
//
//  Created by 秦 道平 on 2017/7/18.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

import Foundation
import GPUImage

public typealias AWGPUImageCaptureSampleBufferCallback = (CMSampleBuffer) -> ()
public typealias AWGPUImageCapturePixelBufferCallback = (CVPixelBuffer, CMTime, CMTime) -> ()

class AWGPUImageMovieWriter: GPUImageMovieWriter {
    var onAudioSampleBuffer : AWGPUImageCaptureSampleBufferCallback? = nil
    var onVideoPixelBuffer : AWGPUImageCapturePixelBufferCallback? = nil
    override func processAudioBuffer(_ audioBuffer: CMSampleBuffer!) {
        super.processAudioBuffer(audioBuffer)
        //        debugPrint("audio buffer:\(audioBuffer)")
//        debugPrint("audio buffer")
        self.onAudioSampleBuffer?(audioBuffer)
    }
    override func newFrameReady(at frameTime: CMTime, at textureIndex: Int) {
        super.newFrameReady(at: frameTime, at: textureIndex)
    }
}

class AWGPUImageRawDataOutput: GPUImageRawDataOutput {
    var onVideoPixelBuffer : AWGPUImageCapturePixelBufferCallback? = nil
    override func newFrameReady(at frameTime: CMTime, at textureIndex: Int) {
        super.newFrameReady(at: frameTime, at: textureIndex)
        self.lockFramebufferForReading()
        let output_bytes = self.rawBytesForImage
        let bytes_per_row = self.bytesPerRowInOutput()
        var pixel_buffer : CVPixelBuffer? = nil
        self.unlockFramebufferAfterReading()
        let size = self.maximumOutputSize()
        let width = size.width
        let height = size.height
        let ret = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                               Int(width), Int(height),
                                               kCVPixelFormatType_32BGRA,
                                               output_bytes!,
                                               Int(bytes_per_row),
                                               nil, nil, nil,
                                               &pixel_buffer)
//        let success = ret == kCVReturnSuccess ? "success" : "false"
//        debugPrint("video output pixel buffer:\(ret)/\(success),\(bytes_per_row),\(frameTime)")
//        debugPrint("video pixel buffer:\(success),\(bytes_per_row)")
        if ret == 0, let _f = self.onVideoPixelBuffer, let _pixel_buffer = pixel_buffer {
            _f(_pixel_buffer,frameTime, kCMTimeInvalid)
        }
        
    }
    public var pixelBufferReleaseCallback : CVPixelBufferReleaseBytesCallback = {
        (p1:UnsafeMutableRawPointer?, p2:UnsafeRawPointer?) -> () in
        debugPrint("PixelBuffer release")
    }
}
