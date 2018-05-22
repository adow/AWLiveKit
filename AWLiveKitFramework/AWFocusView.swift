//
//  AWFocusView.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2018/5/22.
//  Copyright © 2018年 秦 道平. All rights reserved.
//

import UIKit


@objc public protocol AWLiveFocusDelegate : NSObjectProtocol {
    @objc optional func continuousFocus(at point : CGPoint)
}
public class AWFocusView: UIView {

    private let whiteColor = UIColor.white
    private let clearColor = UIColor.clear
    
    public weak var focusDelegate : AWLiveFocusDelegate? = nil
    public var focusTapGesture : UITapGestureRecognizer? = nil
    public var focusPanGesture : UIPanGestureRecognizer? = nil
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = clearColor
        self.isHidden = true
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundColor = clearColor
        self.isHidden = true
    }
    
    override public var intrinsicContentSize: CGSize {
        return CGSize(width: 60.0, height: 60.0)
    }
    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override public func draw(_ rect: CGRect) {
        // Drawing code
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        UIGraphicsPushContext(context)
        context.setStrokeColor(whiteColor.cgColor)
        context.setLineWidth(3.0)
        
        let line_w : CGFloat = rect.width / 3.0
        let line_h : CGFloat = rect.height / 3.0
        
        let line_top_l = [CGPoint(x: 0.0, y: 0.0), CGPoint(x: line_w, y: 0.0)]
        context.strokeLineSegments(between: line_top_l)
        let line_top_r = [CGPoint(x: rect.width - line_w, y: 0.0),
                          CGPoint(x: rect.width, y: 0.0)]
        context.strokeLineSegments(between: line_top_r)
        
        let line_left_t = [CGPoint(x: 0.0, y: 0.0),CGPoint(x: 0.0, y: line_h)]
        context.strokeLineSegments(between: line_left_t)
        let line_left_b = [CGPoint(x: 0.0, y: rect.height - line_h),
                           CGPoint(x: 0.0, y: rect.height)]
        context.strokeLineSegments(between: line_left_b)
        
        let line_right_t = [CGPoint(x: rect.width, y: 0.0), CGPoint(x: rect.width, y: line_h)]
        context.strokeLineSegments(between: line_right_t)
        let line_right_b = [CGPoint(x: rect.width, y: rect.height - line_h),
                            CGPoint(x: rect.width, y: rect.height)]
        context.strokeLineSegments(between: line_right_b)
        
        let line_bottom_l = [CGPoint(x: 0.0, y: rect.height),
                             CGPoint(x: line_w, y: rect.height)]
        context.strokeLineSegments(between: line_bottom_l)
        let line_bottom_r = [CGPoint(x: rect.width - line_w, y: rect.height),
                             CGPoint(x: rect.width, y: rect.height)]
        context.strokeLineSegments(between: line_bottom_r)
        
        UIGraphicsPopContext()
    }
}

// MARK: - DEPRECATED, TapGesture, PanGesture
extension AWFocusView {
    public func installGesture(onView view: UIView, withFocusDelegate focusDelegate : AWLiveFocusDelegate) {
        focusTapGesture = UITapGestureRecognizer(target: self, action: #selector(onFocusTapGesture(recognizer:)))
        view.addGestureRecognizer(focusTapGesture!)

        self.focusPanGesture = UIPanGestureRecognizer(target: self, action: #selector(onFocusPanGesture(recognizer:)))
        self.addGestureRecognizer(focusPanGesture!)
        
        self.focusDelegate = focusDelegate
    }
    public func removeGesture(onView view : UIView) {
        if let gesture = self.focusTapGesture {
            view.removeGestureRecognizer(gesture)
        }
        if let gesture = self.focusPanGesture {
            view.removeGestureRecognizer(gesture)
        }
    }
    @objc func onFocusTapGesture(recognizer : UITapGestureRecognizer) {
        guard let view = recognizer.view else {
            return
        }
        let center = recognizer.location(in: view)
        self.center = center
        self.isHidden = false
        let focusPoint = CGPoint(x: center.x / view.bounds.width ,
                                 y: center.y  / view.bounds.height)
        self.focusDelegate?.continuousFocus?(at: focusPoint)
    }
    
    @objc func onFocusPanGesture(recognizer : UIPanGestureRecognizer) {
        if recognizer.state == .began {
        }
        else if recognizer.state == .ended || recognizer.state == .cancelled {
            guard let view = self.superview else {
                return
            }
            let center = recognizer.location(in: self.superview)
            self.center = center
            self.isHidden = false
            let focusPoint = CGPoint(x: center.x / view.bounds.width ,
                                     y: center.y / view.bounds.height)
            self.focusDelegate?.continuousFocus?(at: focusPoint)
        }
        else if recognizer.state == .changed {
            let center = recognizer.location(in: self.superview)
            self.center = center
            self.isHidden = false
        }
    }
}
