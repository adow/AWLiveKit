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
    var camera : AWGPUImageVideoCamera!
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
                if _beauty == 0 {
                    self.closeFilter()
                }
                else {
                    self.openFilter()
                    beauty_filter.setBeauty(Int32(_beauty))
                }
            }
        }
    }
    open var onAudioSampleBuffer : AWGPUImageCaptureSampleBufferCallback? = nil {
        didSet {
            //self.audioOutput?.onAudioSampleBuffer = onAudioSampleBuffer
            self.camera?.onAudioSampleBuffer = onAudioSampleBuffer
        }
    }
    open var onVideoPixelBuffer : AWGPUImageCapturePixelBufferCallback? = nil {
        didSet {
            self.videoOutput?.onVideoPixelBuffer = onVideoPixelBuffer
        }
    }
    public init?(sessionPreset:String = AVCaptureSessionPresetiFrame960x540,
                 orientation : UIInterfaceOrientation = .portrait,
                 preview : GPUImageView) {
        super.init()
        self.preview = preview
        self.camera = AWGPUImageVideoCamera(sessionPreset: sessionPreset, cameraPosition: .front)
        if let _camera = self.camera {
            _camera.outputImageOrientation = orientation
          
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
            /*
            let movie_file = (cache_dir as NSString).appendingPathComponent("movie.mov")
            NSLog("movie_file:\(movie_file)")
            try? FileManager.default.removeItem(atPath: movie_file)
            let movie_url = URL(fileURLWithPath: movie_file)
            self.audioOutput = AWGPUImageMovieWriter(movieURL: movie_url, size: CGSize(width: width, height: height))
            */
            
            /// filter
            self.filter = GPUImageBeautifyFilter()
            
            /// 默认不使用美颜滤镜
            self.closeFilter()
           
            /// 音频输出到 MovieWriter
            //_camera.audioEncodingTarget = self.audioOutput
            
            _camera.addAudioInputsAndOutputs()
            
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
    
    
    public func openFilter() {
        self.camera?.removeAllTargets()
        self.filter?.removeAllTargets()
        if let _filter = self.filter {
            self.camera?.addTarget(_filter)
        }
        self.filter?.addTarget(self.preview)
        if let _video_output = self.videoOutput {
            self.filter?.addTarget(_video_output)
        }
    }
    public func closeFilter() {
        self.camera?.removeAllTargets()
        self.filter?.removeAllTargets()
        self.camera?.addTarget(self.preview)
        if let _video_output = self.videoOutput {
            self.camera?.addTarget(_video_output)
        }
    }
}
extension AWGPUImageCapture {
    
}
extension AWGPUImageCapture {
    public func start() {
        self.camera?.startCapture()
        self.audioOutput?.startRecording()
    }
    public func stop() {
        self.camera?.stopCapture()
        self.audioOutput?.finishRecording()
    }
}

