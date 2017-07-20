//
//  ViewController.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 16/8/8.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

import UIKit
import AVFoundation
import AWLiveKit

class LiveViewController: UIViewController {

    var live : AWLiveC?
    @IBOutlet var preview : AWLivePreview!
    @IBOutlet var infoLabel : UILabel!
    @IBOutlet var startButton : UIButton!
    @IBOutlet var liveStatLabel : UILabel!
    @IBOutlet var closeButton : UIButton!
    @IBOutlet var cameraSegmentControl : UISegmentedControl!
    @IBOutlet var mirrorButton : UIButton!
    var push_url : String! = "rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84"
    var orientation : UIInterfaceOrientation! = .portrait
    var videoQuality : AWLiveCaptureVideoQuality = ._720
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.showInfo(push_url, duration: 5.0)
        self.startButton.isHidden = true
        /// tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTapGesture(_:)))
        self.view.addGestureRecognizer(tapGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        if self.live == nil {
            ///
            var videoOrientation : AVCaptureVideoOrientation = .portrait
            if orientation == .landscapeRight {
                videoOrientation = .landscapeRight
            }
            else if orientation == .landscapeLeft {
                videoOrientation = .landscapeLeft
            }
            else if orientation == .portrait {
                videoOrientation = .portrait
            }
            else if orientation == .portraitUpsideDown {
                videoOrientation = .portraitUpsideDown
            }
            self.live = AWLiveC(url: self.push_url,
                               onPreview: self.preview,
                               withQuality: self.videoQuality,
                               atOrientation : videoOrientation)
            guard self.live != nil else {
                NSLog("AWLive failed")
                return
            }
            self.live?.push?.delegate = self
            self.live?.liveStat?.delegate = self
            self.cameraSegmentControl.isHidden = (self.live?.canUseFrontCamera != true)
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.live?.stopLive()
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

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.live?.rotateWithCurrentOrientation()
    }
    
    deinit {
        NSLog("LiveViewController release")
    }
    
}

extension LiveViewController {
    fileprivate func showInfo(_ info:String, duration : TimeInterval = 0.0) {
        self.infoLabel.text = info
        self.infoLabel.alpha = 1.0
        if duration > 0.0 {
            UIView.animate(withDuration: duration, animations: {
                self.infoLabel.alpha = 0.0
            })
        }
    }
    @IBAction func onButtonLive(_ sender : UIButton!) {
        guard let _isLive = self.live?.isLive else {
            return
        }
        if !_isLive {
            /// 不要重复创建
            guard self.view.subviews.filter({ (v) -> Bool in
                return v is StartAnimationView
            }).count <= 0 else {
                return
            }
            /// startAnimationView
            let startAnimationView = StartAnimationView()
            startAnimationView.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(startAnimationView)
            let d_startAnimationView = ["sv":startAnimationView]
            let startAnimationView_constraints_h =
                NSLayoutConstraint.constraints(withVisualFormat: "H:|-(0.0)-[sv]-(0.0)-|",
                                               options: [.alignAllCenterX,],
                                               metrics: nil,
                                               views: d_startAnimationView)
            self.view.addConstraints(startAnimationView_constraints_h)
            let startAnimationView_constraint_height =
                NSLayoutConstraint(item: startAnimationView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 80.0)
            let startAnimationView_constraint_centerY =
                NSLayoutConstraint(item: startAnimationView, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1.0, constant: 0.0)
            self.view.addConstraint(startAnimationView_constraint_height)
            self.view.addConstraint(startAnimationView_constraint_centerY)
            startAnimationView.startAnimation(completionBlock: {
                [weak self] in
                self?.live?.startLive()
                self?.showInfo("Start", duration: 5.0)
            })
        }
        else {
            self.live?.stopLive()
            self.showInfo("Stop")
        }
    }
    @IBAction func onCameraChanged(_ sender : UISegmentedControl!) {
        if sender.selectedSegmentIndex == 0 {
            self.live?.useFrontCamera = false
        }
        else if sender.selectedSegmentIndex == 1 {
            self.live?.useFrontCamera = true
        }
        
    }
    @IBAction func onButtonMirror(_ sender : UIButton!) {
        sender.isSelected = !sender.isSelected
        self.live?.mirror = sender.isSelected
    }
    @IBAction func onButtonClose(_ sender : UIButton!) {
        self.dismiss(animated: true) { 
            
        }
    }
    func onTapGesture(_ recognizer:UITapGestureRecognizer) {
        self.toggleUI()
    }
    fileprivate func toggleUI() {
        let ui : [UIView] = [self.cameraSegmentControl, self.mirrorButton, self.liveStatLabel]
        UIView.animate(withDuration: 0.5, delay: 0.5, options: [.curveEaseOut,.allowUserInteraction], animations: {
            ui.forEach({ (v) in
                if v.alpha == 1.0 {
                    v.alpha = 0.0
                }
                else {
                    v.alpha = 1.0
                }
            })
        }, completion: { (completed) in
            
        })
        
    }
}
extension LiveViewController : AWLivePushDeletate,AWLiveStatDelegate {
    func push(_ push: AWLivePushC, connectedStateChanged state: AWLiveConnectState) {
        self.startButton.isHidden = (state != .Connected)
        self.showInfo("\(state)",duration: 5.0)
    }
    func pushLiveChanged(_ push: AWLivePushC) {
        self.startButton.isSelected = push.isLive
        self.closeButton.isHidden = push.isLive
        self.showInfo("\(push.isLive ? "start" : "stop")", duration: 5.0)
    }
    func updateLiveStat(stat: AWLiveStat) {
        self.liveStatLabel.text = stat.outputDescription
    }
}