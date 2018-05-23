//
//  AWLivePreview.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 16/8/8.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

import UIKit
import AVFoundation

public class AWLivePreview: UIView {

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public class override var layerClass:(AnyClass){
        return AVCaptureVideoPreviewLayer.self
    }
    
    public var session:AVCaptureSession!{
        get{
            let layer=self.layer as! AVCaptureVideoPreviewLayer
            return layer.session
        }
        set{
            let layer=self.layer as! AVCaptureVideoPreviewLayer
            layer.videoGravity = .resizeAspectFill
            layer.session=newValue
        }
    }
    
    public var connection : AVCaptureConnection? {
        if let _layer = (self.layer as? AVCaptureVideoPreviewLayer), let connection = _layer.connection {
            return connection
        }
        else {
            return nil
        }
    }
    
    public var mirror : Bool {
        get {
            return self.connection?.isVideoMirrored ?? false
        }
        set {
            if let _connection = self.connection {
                _connection.automaticallyAdjustsVideoMirroring = false
                _connection.isVideoMirrored = newValue
            }
        }
        
    }
    
    public var videoOrientation : AVCaptureVideoOrientation? {
        get {
            return self.connection?.videoOrientation
        }
        set {
            if let orientation = newValue {
                self.connection?.videoOrientation = orientation
            }
        }
    }
}
