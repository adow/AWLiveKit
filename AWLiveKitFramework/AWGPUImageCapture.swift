//
//  AWGPUImageCapture.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/7/18.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

import UIKit
import GPUImage

/// 缓存目录
fileprivate let cache_dir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
/// documents
fileprivate let document_dir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]

open class AWGPUImageCapture: NSObject {
    var camera : GPUImageVideoCamera!
    fileprivate var filter : GPUImageFilterGroup!
    var preview : GPUImageView!
    fileprivate var videoOutput : AWGPUImageRawDataOutput!
    fileprivate var audioOutput : AWGPUImageMovieWriter!
    
    open var cameraPosition : AVCaptureDevicePosition? {
        return self.camera?.cameraPosition()
    }
    open var beauty : Int? {
        didSet {
            if let _beauty = beauty, let beauty_filter = self.filter as? GPUImageBeautifyFilter {
                beauty_filter.setBeauty(Int32(_beauty))
            }
        }
    }
    open var onAudioSampleBuffer : AWGPUImageCaptureSampleBufferCallback? = nil {
        didSet {
            self.audioOutput.onAudioSampleBuffer = onAudioSampleBuffer
        }
    }
    open var onVideoPixelBuffer : AWGPUImageCapturePixelBufferCallback? = nil {
        didSet {
            self.videoOutput.onVideoPixelBuffer = onVideoPixelBuffer
        }
    }
    public init?(sessionPreset:String = AVCaptureSessionPresetiFrame960x540,
                 orientation : UIInterfaceOrientation = .portrait,
                 preview : GPUImageView) {
        super.init()
        self.preview = preview
        self.camera = GPUImageVideoCamera(sessionPreset: sessionPreset, cameraPosition: .front)
        if let _camera = self.camera {
            _camera.outputImageOrientation = orientation
           
            /// filter
            self.filter = GPUImageBeautifyFilter()
            _camera.addTarget(self.filter)
            
            /// preview output
//            self.preview = GPUImageView()
            /// video output
            var width : Int = 0
            var height : Int = 0
            if let output = self.camera.captureSession.outputs.last as? AVCaptureVideoDataOutput{
                NSLog("output:\(output.videoSettings)")
                if let settings = output.videoSettings {
                    let w = (settings["Width"] as? Int) ?? 0
                    let h = (settings["Height"] as? Int) ?? 0
                    if orientation == .portrait || orientation == .portraitUpsideDown {
                        width = min(w,h)
                        height = max(w,h)
                    }
                    else {
                        width = max(w,h)
                        height = min(w,h)
                    }
                }
            }
            NSLog("width:\(width),height:\(height)")
            if width < 0 || height < 0 {
                return nil
            }
            self.videoOutput = AWGPUImageRawDataOutput(imageSize: CGSize(width:width, height: height), resultsInBGRAFormat: true)
            /// audio output
            let movie_file = (cache_dir as NSString).appendingPathComponent("movie.mov")
            NSLog("movie_file:\(movie_file)")
            try? FileManager.default.removeItem(atPath: movie_file)
            let movie_url = URL(fileURLWithPath: movie_file)
            self.audioOutput = AWGPUImageMovieWriter(movieURL: movie_url, size: CGSize(width: width, height: height))
            
            self.filter.addTarget(preview)
            self.filter.addTarget(self.videoOutput)
            /// 视频不要再次输出到 MovieWriter, 使用 RawDataOutput 输出
//            self.filter.addTarget(self.audioOutput)
           
            /// 音频输出到 MovieWriter
            _camera.audioEncodingTarget = self.audioOutput
            /// 
//            _camera.startCapture()
        }
        else {
            return nil
        }
    }
    open func rotateCamera() {
        self.camera.rotateCamera()
    }
    
    deinit {
        NSLog("AWGPUImageCapture release")
    }
}
extension AWGPUImageCapture {
    public func start() {
        self.camera.startCapture()
        self.audioOutput.startRecording()
    }
    public func stop() {
        self.camera.stopCapture()
        self.audioOutput.finishRecording()
    }
}

