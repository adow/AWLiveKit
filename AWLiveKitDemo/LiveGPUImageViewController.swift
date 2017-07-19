//
//  LiveGPUImageViewController.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/7/18.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

import UIKit
import GPUImage
import AWLiveKit

class LiveGPUImageViewController: UIViewController {

    var orientation : UIInterfaceOrientation! = .portrait
    @IBOutlet weak var preview : GPUImageView!
    var capture : AWGPUImageCapture!
    var push : AWLivePushC!
    @IBOutlet var startButton : UIButton!
    @IBOutlet var closeButton : UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        /// push
        push = AWLivePushC(url: "rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84")
        push.delegate = self
        ///
        let videoQuality : AWLiveCaptureVideoQuality = ._540i
        let video_size = videoQuality.videoSizeForOrientation(AVCaptureVideoOrientation(rawValue: self.orientation.rawValue)!)
        let ret = aw_video_encoder_init(Int32(video_size.width),
                                        Int32(video_size.height),
                                        Int32(videoQuality.recommandVideoBiterates.bitrates),
                                        Int32(videoQuality.recommandVideoBiterates.recommandedFPS.fps),
                                        videoQuality.recommandVideoBiterates.recommandedProfile.profile)
        NSLog("ret:\(ret)")
        // Do any additional setup after loading the view.
        capture = AWGPUImageCapture(sessionPreset: videoQuality.sessionPreset,
                                    orientation: orientation,
                                    preview: self.preview)
        capture.onAudioSampleBuffer = {
            [weak self] (sampleBuffer) -> () in
            guard let _self = self,let _push = _self.push, _push.isLive else {
                return
            }
//            NSLog("audio sample buffer")
            if let buffer_list = aw_audio_encode(sampleBuffer) {
                NSLog("audio buffer list:\(buffer_list)")
                _self.push.pushAudioBufferList(buffer_list.pointee)
                aw_audio_release(buffer_list)
            }
            else {
                NSLog("no audio encoded")
            }
            
        }
        capture.onVideoPixelBuffer = {
            [weak self](pixelBuffer, presentation_time, duration) -> () in
            guard let _self = self,let _push = _self.push, _push.isLive else {
                return
            }
//            NSLog("video sample buffer")
            aw_video_encode_pixelbuffer(pixelBuffer, presentation_time, duration, { (sample_buffer, context) in
                if let _p = sample_buffer {
//                    NSLog("video sample buffer encoded:\(_p)")
                    NSLog("video sample buffer encoded")
                    let _weak_push = unsafeBitCast(context, to: AWLivePushC.self)
                    _weak_push.pushVideoSampleBuffer(_p)
                }
                else {
                    NSLog("no video encoded")
                }
                
            }, unsafeBitCast(_self.push, to: UnsafeMutableRawPointer.self))
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.capture?.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.capture?.stop()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        //        return UIInterfaceOrientationMask(rawValue: UInt(self.orientation.rawValue))
        if orientation == .landscapeRight {
            return .landscapeRight
        }
        else if orientation == .landscapeLeft {
            return .landscapeLeft
        }
        else if orientation == .portrait {
            return .portrait
        }
        else if orientation == .portraitUpsideDown {
            return .portraitUpsideDown
        }
        else {
            return .portrait
        }
    }
    override var shouldAutorotate : Bool {
        return false
    }
    override var preferredInterfaceOrientationForPresentation : UIInterfaceOrientation {
        return self.orientation
    }
    
}
extension LiveGPUImageViewController {
    @IBAction func onButtonClose(sender:UIButton) {
        self.dismiss(animated: true) {
            
        }
    }
    @IBAction func onButtonCamera(sender:UIButton) {
        self.capture?.rotateCamera()
    }
    @IBAction func onButtonStart(sender:UIButton) {
        self.push?.start()
    }
    @IBAction func onBeautySegment(sender:UISegmentedControl) {
        self.capture?.beauty = sender.selectedSegmentIndex
    }
}

extension LiveGPUImageViewController : AWLivePushDeletate {
    func push(_ push: AWLivePushC, connectedStateChanged state: AWLiveConnectState) {
        self.startButton.isHidden = (state != .Connected)
    }
    func pushLiveChanged(_ push: AWLivePushC) {
        self.startButton.isSelected = push.isLive
        self.closeButton.isHidden = push.isLive
    }
}

