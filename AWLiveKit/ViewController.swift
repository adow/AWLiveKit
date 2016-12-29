//
//  ViewController.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 16/8/8.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var capture : AWLiveCapture!
    var videoEncoder : AWVideoEncoder!
    var audioEncoder : AWAudioEncoder!
    var push : AWLivePush!
    var preview : AWLivePreview!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let videoQuality = AWLiveCaptureVideoQuality._1080
        /// push
//        let push_url = "rtmp://m.push.wifiwx.com:1935/live?sign=0547f0bc0208e98f9dc89cdf443dc75e4e7a464a&id=62&timestamp=1470812052&nonce=99774&adow=adow/wifiwx-62"
//        let push_url = "rtmp://m.push.wifiwx.com:1935/live?ukey=8mdwmb6zf&pub=0512688f0831a314594165131bbb3399/wifiwx-84"
        let push_url = "rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84"
        push = AWLivePush(url: push_url)
        
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
            self?.capture.start()
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
        
        /// preview
        preview = capture.previewView
        preview.frame = self.view.bounds
        self.view.addSubview(preview)
        self.view.translatesAutoresizingMaskIntoConstraints = false
        preview.translatesAutoresizingMaskIntoConstraints = false
        let layout_preview = ["preview":preview]
        let preview_constraintsH = NSLayoutConstraint.constraintsWithVisualFormat("H:|-(-16.0)-[preview]-(-16.0)-|", options: .AlignAllCenterX, metrics: nil, views: layout_preview)
        let preview_constraintsV = NSLayoutConstraint.constraintsWithVisualFormat("V:|-(-16.0)-[preview]-(-16.0)-|", options: .AlignAllCenterY, metrics: nil, views: layout_preview)
        self.view.addConstraints(preview_constraintsH)
        self.view.addConstraints(preview_constraintsV)
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.sharedApplication().idleTimerDisabled = true
//        capture.start()
        
        
    }
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
    }
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        videoEncoder?.close()
        capture?.stop()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

