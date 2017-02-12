//
//  StartView.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/2/12.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

import UIKit
class StartAnimationView: UIView {
    var titles : [String] = ["READY","3","2","1","GO"]
    var animationView : UIView!
    var animationIndex : Int = 0
    var onGo : (()->())!
    var itemHeight : CGFloat {
        return self.bounds.height
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.clipsToBounds = true
        self.isUserInteractionEnabled = false
        self.translatesAutoresizingMaskIntoConstraints = false
        /// backgrounView
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(backgroundView)
        let d_backgroundView = ["bg":backgroundView]
        let backgroundView_constraints_h =
            NSLayoutConstraint.constraints(withVisualFormat: "|-(0.0)-[bg]-(0.0)-|",
                        options: [.alignAllCenterX,.alignAllCenterY],
                        metrics: nil,
                        views: d_backgroundView)
        let backgroundView_constraints_v =
            NSLayoutConstraint.constraints(withVisualFormat: "V:|-(0.0)-[bg]-(0.0)-|",
                        options: [.alignAllCenterX,.alignAllCenterY],
                        metrics: nil,
                        views: d_backgroundView)
        self.addConstraints(backgroundView_constraints_h)
        self.addConstraints(backgroundView_constraints_v)
        /// animationView
        animationView = UIView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(animationView)
        let animationView_constriant_top =
            NSLayoutConstraint(item: animationView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0.0)
        let animationView_constraint_centerX =
            NSLayoutConstraint(item: animationView, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1.0, constant: 0.0)
        let animationView_constraint_height =
            NSLayoutConstraint(item: animationView, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1.0, constant: 0.0)
        self.addConstraints([animationView_constriant_top,animationView_constraint_centerX,animationView_constraint_height])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    deinit {
        NSLog("StartAnimationView release")
    }
    /// 绘制每一个
    fileprivate func makeTitleViews() {
        /// 先删除原来的
        self.animationView.subviews.forEach { (v) in
            v.removeFromSuperview()
        }
        zip(0...titles.count, titles).forEach { (index,title) -> () in
            let titleView = UILabel()
            titleView.translatesAutoresizingMaskIntoConstraints = false
            titleView.font = UIFont.systemFont(ofSize: self.itemHeight)
            titleView.textAlignment = .center
            titleView.textColor = UIColor.white
            titleView.text = self.titles[index]
            animationView.addSubview(titleView)
            let top : CGFloat = itemHeight * CGFloat(index)
            let titleView_constraint_top =
                NSLayoutConstraint(item: titleView,
                                   attribute:.top ,
                                   relatedBy: .equal,
                                   toItem: animationView,
                                   attribute: .top,
                                   multiplier: 1.0,
                                   constant: top)
            let titleView_constraint_width =
                NSLayoutConstraint(item: titleView,
                                   attribute: .width,
                                   relatedBy: .equal,
                                   toItem: animationView,
                                   attribute: .width,
                                   multiplier: 1.0,
                                   constant: 0.0)
            let titleView_constraint_height =
                NSLayoutConstraint(item: titleView,
                                   attribute: .height,
                                   relatedBy: .equal,
                                   toItem: animationView,
                                   attribute: .height,
                                   multiplier: 1.0,
                                   constant: 0.0)
            let titleView_constraint_centerX =
                NSLayoutConstraint(item: titleView,
                                   attribute: .centerX,
                                   relatedBy: .equal,
                                   toItem: animationView,
                                   attribute: .centerX,
                                   multiplier: 1.0,
                                   constant: 0.0)
            self.animationView.addConstraints([titleView_constraint_top,
                                               titleView_constraint_width,
                                               titleView_constraint_height,
                                               titleView_constraint_centerX])
        }
        
        
    }
    fileprivate func next() {
        self.animationIndex += 1
        guard self.animationIndex <= self.titles.count else {
            NSLog("GO")
            self.onGo()
            self.removeFromSuperview()
            return
        }
        
        let delay = self.animationIndex == 1 ? 0.0 : 0.7
        UIView.animate(withDuration: 0.3, delay: delay, options: UIViewAnimationOptions.curveEaseOut, animations: {
            let target_y = -1.0 * CGFloat(self.animationIndex) * self.itemHeight
            self.animationView.transform = CGAffineTransform(translationX: 0.0, y: target_y)
            
        }) { (completed) in
            self.next()
        }
    }
    /// 开始倒计时的动画
    func startAnimation(completionBlock : @escaping (()-> ())) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { () -> Void in
            self.onGo = completionBlock
            self.makeTitleViews()
            self.animationIndex = 0
            self.next()
        }
        
    }
}

