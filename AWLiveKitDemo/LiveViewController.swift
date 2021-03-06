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

public enum LiveViewControllerType : Int {
    case simple = 0, beauty = 1
}

class LiveViewController: UIViewController {
    var live : AWLiveBase?
    //@IBOutlet var preview : AWLivePreview!
    @IBOutlet var infoLabel : UILabel!
    @IBOutlet var startButton : UIButton!
    @IBOutlet var liveStatLabel : UILabel!
    @IBOutlet var closeButton : UIButton!
    @IBOutlet var switchCameraButton : UIButton!
    @IBOutlet var beautySegment : UISegmentedControl!
    @IBOutlet var touchView : UIView!
    @IBOutlet var focusView : AWFocusView!
    var push_url : String! = "rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84"
    var orientation : UIInterfaceOrientation! = .portrait
    var videoQuality : AWLiveCaptureVideoQuality = ._720
    var liveType : LiveViewControllerType = .simple
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        guard let av_orientation = AVCaptureVideoOrientation(rawValue:self.orientation.rawValue) else {
            return
        }
        /// live
        if self.liveType == .simple {
            self.live = AWLiveSimple(url: self.push_url, withQuality: videoQuality, atOrientation: av_orientation)
        }
        else if self.liveType == .beauty {
            self.live = AWLiveBeauty(url: self.push_url, withQuality: videoQuality, atOrientation: av_orientation)
        }
        guard let _live = self.live, let preview = _live.connectedPreview else {
            debugPrint("create live failed")
            return
        }
        _live.push?.delegate = self
        _live.liveStat?.delegate = self
        /// preview
        preview.backgroundColor = UIColor.darkGray
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.contentMode = .scaleAspectFill
        preview.isUserInteractionEnabled = false
        self.view.insertSubview(preview, at: 0)
        let d_preview = ["preview":preview]
        let preview_constraintsH = NSLayoutConstraint.constraints(withVisualFormat: "H:|-(0.0)-[preview]-(0.0)-|", options: .alignAllCenterX, metrics: nil, views: d_preview)
        let preview_constraintsV = NSLayoutConstraint.constraints(withVisualFormat: "V:|-(0.0)-[preview]-(0.0)-|", options: .alignAllCenterY, metrics: nil, views: d_preview)
        self.view.addConstraints(preview_constraintsH)
        self.view.addConstraints(preview_constraintsV)
        ///
        self.showInfo(push_url, duration: 5.0)
//        self.startButton.isHidden = true
        ///
        if self.liveType == .simple {
            self.beautySegment.isHidden = true
        }
       
        if self.live is AWLiveSimple {
            let focusTapGesture = UITapGestureRecognizer(target: self, action: #selector(onFocusTapGesture(recognizer:)))
            focusTapGesture.delegate = self
            self.touchView.addGestureRecognizer(focusTapGesture)
            
            let focusPanGesture = UIPanGestureRecognizer(target: self, action: #selector(onFocusPanGesture(recognizer:)))
            focusPanGesture.delegate = self
            self.focusView.addGestureRecognizer(focusPanGesture)
            
            let zoomPinGesture = UIPinchGestureRecognizer(target: self, action: #selector(onZoomPinGesture(recoginzer:)))
            zoomPinGesture.delegate = self
            self.touchView.addGestureRecognizer(zoomPinGesture)
        }
        /// tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onUITapGesture))
        tapGesture.delegate = self
        self.touchView.addGestureRecognizer(tapGesture)
        
//        let zoomTapGesture = UITapGestureRecognizer(target: self, action: #selector(onZoomTapGesture(recognzier:)))
//        zoomTapGesture.numberOfTapsRequired = 2
//        zoomTapGesture.delegate = self
//        self.touchView.addGestureRecognizer(zoomTapGesture)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        self.live?.startCapture()
        
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.live?.stopCapture()
        self.live?.stopLive()
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
    }
    
    deinit {
        if self.live is AWLiveSimple {
            self.focusView.removeGesture(onView: self.touchView)
        }
        debugPrint("LiveViewController release")
    }
    
}

extension LiveViewController : UIGestureRecognizerDelegate{
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
        guard let _live = self.live else {
            return
        }
        guard let _isLive = _live.isLive else {
            return
        }
        if !_isLive {
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
                startAnimationView.removeFromSuperview()
            })
        }
        else {
            self.live?.stopLive()
            self.showInfo("Stop")
        }
    }
    @IBAction func onButtonSwitchCamera(_sender:UIButton) {
        self.live?.switchCamera()
    }
    
    @IBAction func onButtonClose(_ sender : UIButton!) {
        self.dismiss(animated: true) { 
            
        }
    }
    @IBAction func onBeautySegment(_ sender:UISegmentedControl!) {
        self.live?.beauty = sender.selectedSegmentIndex
    }
    
    // MARK: Gesture
    @objc func onUITapGesture(_ recognizer:UITapGestureRecognizer) {
        self.toggleUI()
        guard let capture = (self.live as? AWLiveSimple)?.capture else {
            return
        }
        capture.startZoom()
        capture.resetZoom()
        capture.endZoom()
    }
    fileprivate func toggleUI() {
        let ui : [UIView] = [self.switchCameraButton,self.beautySegment, self.liveStatLabel]
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
    
    @objc func onZoomPinGesture(recoginzer : UIPinchGestureRecognizer) {
//        debugPrint(recoginzer.scale)
        guard let capture = (self.live as? AWLiveSimple)?.capture else {
            return
        }
        if recoginzer.state == .began {
            capture.startZoom()
        }
        else if recoginzer.state == .ended || recoginzer.state == .cancelled {
            capture.endZoom()
        }
        else if recoginzer.state == .changed {
            capture.zoom(scaleAdd: recoginzer.scale)
        }
    }
    
    @objc func onZoomTapGesture(recognzier : UITapGestureRecognizer) {
        guard let capture = (self.live as? AWLiveSimple)?.capture else {
            return
        }
        capture.startZoom()
        capture.resetZoom()
        capture.endZoom()
    }
    
    @objc func onFocusTapGesture(recognizer : UITapGestureRecognizer) {
        guard let view = recognizer.view else {
            return
        }
        let center = recognizer.location(in: view)
        self.focusView.center = center
        self.focusView.isHidden = false
        let focusPoint = CGPoint(x: center.x / view.bounds.width ,
                                 y: center.y  / view.bounds.height)
        //self.focusDelegate?.continuousFocus?(at: focusPoint)
        self.continuousFocus(at: focusPoint)
    }
    
    @objc func onFocusPanGesture(recognizer : UIPanGestureRecognizer) {
        if recognizer.state == .began {
        }
        else if recognizer.state == .ended || recognizer.state == .cancelled {
            let center = recognizer.location(in: self.touchView)
            self.focusView.center = center
            self.focusView.isHidden = false
            let focusPoint = CGPoint(x: center.x / view.bounds.width ,
                                     y: center.y / view.bounds.height)
//            self.focusDelegate?.continuousFocus?(at: focusPoint)
            self.continuousFocus(at: focusPoint)
        }
        else if recognizer.state == .changed {
            let center = recognizer.location(in: self.touchView)
            self.focusView.center = center
            self.focusView.isHidden = false
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        debugPrint(gestureRecognizer,otherGestureRecognizer)
        return true
    }
    
}

// MARK: - push
extension LiveViewController : AWLivePushDeletate,AWLiveStatDelegate {
    func pushError(_ code: Int, withMessage message: String) {
        self.live?.liveStat?.pushError = "\(code):\(message)"
//        self.showInfo("\(code):\(message)",duration: 5)
    }
    func resetPushError() {
        self.live?.liveStat?.pushError = nil
    }
    func push(_ push: AWLivePushC, connectedStateChanged state: AWLiveConnectState) {
//        self.startButton.isHidden = (state != .Connected)
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

// MARK: - Focus
extension LiveViewController : AWLiveFocusDelegate {
    func continuousFocus(at point: CGPoint) {
        debugPrint("point",point)
        guard let capture = (self.live as? AWLiveSimple)?.capture else {
            return
        }
        capture.continuousFocusBegin()
        capture.continuousFocusUpdate(at: point)
        capture.continuousFocusEnd()
        
    }
}
