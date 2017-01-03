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

    class override func layerClass()->(AnyClass){
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
            return self.connection?.videoMirrored ?? false
        }
        set {
            if let _connection = self.connection {
                _connection.automaticallyAdjustsVideoMirroring = false
                _connection.videoMirrored = newValue
            }
        }
        
    }
}
