//
//  AWLivePreview.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 16/8/8.
//  Copyright © 2016年 秦 道平. All rights reserved.
//

import UIKit
import AVFoundation

class AWLivePreview: UIView {

    class override var layerClass:(AnyClass){
        return AVCaptureVideoPreviewLayer.self
    }
    
    var session:AVCaptureSession!{
        get{
            let layer=self.layer as! AVCaptureVideoPreviewLayer
            return layer.session
        }
        set{
            let layer=self.layer as! AVCaptureVideoPreviewLayer
            layer.session=newValue
        }
    }
    var connection : AVCaptureConnection? {
        if let connection = (self.layer as? AVCaptureVideoPreviewLayer)?.connection {
            return connection
        }
        else {
            return nil
        }
    }
    var mirror : Bool {
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
    var videoOrientation : AVCaptureVideoOrientation? {
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
