//
//  ViewController.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 16/8/8.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    var capture : AWLiveCapture!
    var videoEncoder : AWVideoEncoder!
    var audioEncoder : AWAudioEncoder!
    var push : AWLivePush2!
    @IBOutlet var preview : AWLivePreview!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let videoQuality = AWLiveCaptureVideoQuality._720
        /// push
        let push_url = "rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84"
        push = AWLivePush2(url: push_url)
        
        /// capture
        capture = AWLiveCapture(sessionPreset: videoQuality.sessionPreset,
                                orientation: .Portrait)
        capture.onVideoSampleBuffer = {
            [weak self](sampleBuffer) -> () in
            self?.videoEncoder?.encodeSampleBuffer(sampleBuffer)
            
        }
        capture.onAudioSampleBuffer = {
            [weak self](sampleBuffer) -> () in
//            print("audio")
            self?.audioEncoder?.encodeSampleBuffer(sampleBuffer)
        }
        capture.onReady = {
            [weak self] in
            guard let _self = self else {
                return
            }

            _self.capture.connectPreView(_self.preview)
            _self.capture.start()
        }
        
        /// videoEncoder
        videoEncoder = AWVideoEncoder(outputSize: videoQuality.videoSizeForOrientation(.Portrait),
                                      bitrate: videoQuality.recommandVideoBiterates,
                                      fps:videoQuality.recommandVideoBiterates.recommandedFPS,
                                      profile: videoQuality.recommandVideoBiterates.recommandedProfile)
        videoEncoder.onEncoded = {
            [weak self](sampleBuffer) -> () in
            //            print("video encoded")
            self?.push?.pushVideoSampleBuffer(sampleBuffer) /// push
        }
        /// audioEncoder
        audioEncoder = AWAudioEncoder()
        audioEncoder.onEncoded = {
            [weak self](bufferList) -> () in
            self?.push?.pushAudioBufferList(bufferList) /// push
        }
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.sharedApplication().idleTimerDisabled = true
    }
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
    }
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        videoEncoder?.close()
        capture?.stop()
    }
//    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
//        return .LandscapeRight
//    }
//    override func shouldAutorotate() -> Bool {
//        return true
//    }
//    override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
//        return .LandscapeRight
//    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let connection = (self.preview?.layer as? AVCaptureVideoPreviewLayer)?.connection {
            let device_orientation = UIApplication.sharedApplication().statusBarOrientation
            switch device_orientation {
            case .LandscapeLeft:
                connection.videoOrientation = .LandscapeLeft
                self.capture.videoOrientation = .LandscapeLeft
            case .LandscapeRight:
                connection.videoOrientation = .LandscapeRight
                self.capture.videoOrientation = .LandscapeRight
            case .Portrait:
                connection.videoOrientation = .Portrait
                self.capture.videoOrientation = .Portrait
            case .PortraitUpsideDown:
                connection.videoOrientation = .PortraitUpsideDown
                self.capture.videoOrientation = .PortraitUpsideDown
            default:
                connection.videoOrientation = .Portrait
                self.capture.videoOrientation = .Portrait
            }
        }
    }


}

