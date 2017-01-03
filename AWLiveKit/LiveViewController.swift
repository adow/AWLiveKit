//
//  ViewController.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 16/8/8.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

import UIKit
import AVFoundation

class LiveViewController: UIViewController {

    var live : AWLive!
    @IBOutlet var preview : AWLivePreview!
    @IBOutlet var infoLabel : UILabel!
    @IBOutlet var startButton : UIButton!
    var push_url : String! = "rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84"
    var orientation : UIInterfaceOrientation! = .Portrait
    var videoQuality : AWLiveCaptureVideoQuality = ._720
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.showInfo(push_url, duration: 5.0)
        var videoOrientation : AVCaptureVideoOrientation = .Portrait
        if orientation == .LandscapeRight {
            videoOrientation = .LandscapeRight
        }
        else if orientation == .LandscapeLeft {
            videoOrientation = .LandscapeLeft
        }
        else if orientation == .Portrait {
            videoOrientation = .Portrait
        }
        else if orientation == .PortraitUpsideDown {
            videoOrientation = .PortraitUpsideDown
        }
        self.live = AWLive(url: self.push_url,
                           onPreview: self.preview,
                           withQuality: self.videoQuality,
                           atOrientation : videoOrientation)
        
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
        self.live.close()
    }
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
//        return UIInterfaceOrientationMask(rawValue: UInt(self.orientation.rawValue))
        if orientation == .LandscapeRight {
            return .LandscapeRight
        }
        else if orientation == .LandscapeLeft {
            return .LandscapeLeft
        }
        else if orientation == .Portrait {
            return .Portrait
        }
        else if orientation == .PortraitUpsideDown {
            return .PortraitUpsideDown
        }
        else {
            return .Portrait
        }
    }
    override func shouldAutorotate() -> Bool {
        return false
    }
    override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
        return self.orientation
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.live.rotateWithCurrentOrientation()
    }
    
}

extension LiveViewController {
    private func showInfo(info:String, duration : NSTimeInterval = 0.0) {
        self.infoLabel.text = info
        self.infoLabel.alpha = 1.0
        if duration > 0.0 {
            UIView.animateWithDuration(duration, animations: {
                self.infoLabel.alpha = 0.0
            })
        }
    }
    @IBAction func onButtonLive(sender : UIButton!) {
        if !live.live {
            live.startLive()
            sender.selected = true
            self.showInfo("Start", duration: 5.0)
        }
        else {
            live.stopLive()
            sender.selected = false
            self.showInfo("Stop")
        }
    }
    @IBAction func onCameraChanged(sender : UISegmentedControl!) {
        if sender.selectedSegmentIndex == 0 {
            self.live.frontCamera = false
        }
        else if sender.selectedSegmentIndex == 1 {
            self.live.frontCamera = true
        }
        
    }
    @IBAction func onButtonMirror(sender : UIButton!) {
        sender.selected = !sender.selected
        self.live.mirror = sender.selected
    }
}
