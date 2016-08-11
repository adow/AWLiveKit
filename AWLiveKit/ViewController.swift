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
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let videoQuality = AWLiveCaptureVideoQuality._1080
        /// push
        let push_url = "rtmp://m.push.wifiwx.com:1935/live?sign=0547f0bc0208e98f9dc89cdf443dc75e4e7a464a&id=62&timestamp=1470812052&nonce=99774&adow=adow/wifiwx-62"
        push = AWLivePush(url: push_url)
        /// videoEncoder
        videoEncoder = AWVideoEncoder(outputSize: videoQuality.videoSizeForOrientation(.Portrait),
                                      bitrate: videoQuality.recommandVideoBiterates,
                                      fps:._30)
        videoEncoder.onEncoded = {
            [weak self](sampleBuffer) -> () in
//            print("video encoded")
            self?.push.pushVideoSampleBuffer(sampleBuffer)
        }
        /// audioEncoder
        audioEncoder = AWAudioEncoder()
        audioEncoder.onEncoded = {
            [weak self](bufferList) -> () in
            self?.push.pushAudioBufferList(bufferList)
        
        }
        /// capture
        capture = AWLiveCapture(videoQuality: videoQuality,
                                orientation: .Portrait)
        capture.onVideoSampleBuffer = {
            [weak self](sampleBuffer) -> () in
            self?.videoEncoder.encodeSampleBuffer(sampleBuffer)
            
        }
        capture.onAudioSampleBuffer = {
            [weak self](sampleBuffer) -> () in
//            print("audio")
            self?.audioEncoder.encodeSampleBuffer(sampleBuffer)
        }
        
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        let preview = capture.previewView
        preview.frame = self.view.bounds
        self.view.addSubview(preview)
        capture.start()
        
        
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

