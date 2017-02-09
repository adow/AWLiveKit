//
//  StartViewController.swift
//  AWLiveKit
//
//  Created by 秦 道平 on 2017/1/3.
//  Copyright © 2017年 秦 道平. All rights reserved.
//

import UIKit

class StartViewController: UIViewController {

    @IBOutlet weak var urlTextField : UITextField!
    @IBOutlet weak var qualityPicker : UIPickerView!
    @IBOutlet weak var orientationSegment : UISegmentedControl!
    var videoQualities : [AWLiveCaptureVideoQuality] = [._480,._540i, ._720,  ._1080, ._4k]
    var videoLandscape : Bool = true
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.urlTextField.text = "rtmp://m.push.wifiwx.com:1935/live?ukey=bcr63eydi&pub=f0b7331b420e3621e01d012642f0a355/wifiwx-84"
        self.qualityPicker.selectRow(2, inComponent: 0, animated: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var shouldAutorotate : Bool {
        return false
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return .portrait
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segue_start_to_live" {
            guard let url = urlTextField.text, url != "" else {
                return
            }
            
            
            let videoQuality = videoQualities[qualityPicker.selectedRow(inComponent: 0)]
            //let landscape = (self.orientationSegment.selectedSegmentIndex == 0)
            let landscape = self.videoLandscape
            if let destinationViewController = segue.destination as? LiveViewController {
                destinationViewController.push_url = url
                destinationViewController.orientation =  landscape ? .landscapeRight : .portrait
                destinationViewController.videoQuality = videoQuality
                
            }
        }
    }
    @IBAction func onButtonStart(sender:UIButton) {
        let alert = UIAlertController(title: "进入直播", message: "选择屏幕方向", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "横屏", style: .destructive, handler: { (_) in
            self.videoLandscape = true
            self.performSegue(withIdentifier: "segue_start_to_live", sender: sender)
        }))
        alert.addAction(UIAlertAction(title: "竖屏", style: .default, handler: { (_) in
            self.videoLandscape = false
            self.performSegue(withIdentifier: "segue_start_to_live", sender: sender)
        }))
        self.present(alert, animated: true) {
        }
    }
    

}
extension StartViewController : UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return videoQualities.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return videoQualities[row].description
    }
}
