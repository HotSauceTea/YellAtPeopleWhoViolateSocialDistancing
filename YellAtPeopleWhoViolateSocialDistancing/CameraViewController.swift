//
//  CameraViewController.swift
//
//

import UIKit
import AVFoundation
import Photos
import CoreVideo
import MobileCoreServices
import Accelerate
import CoreMotion
import RealityKit
import ARKit

class DataViewController : UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {

    var pickerData: [[String]] = [["Height:"], []]
    static var chosenFeet = "5"
    static var chosenInches = "7"
    static var chosenRow = 67
    static let shoulderBodyProportion = 0.82
    static var useHumanHeight = true

    
    @IBOutlet weak var segmentedControlButton: UISegmentedControl!
    
    @IBAction func changeSegmentedControl(_ sender: UISegmentedControl) {
        switch segmentedControlButton.selectedSegmentIndex {
            case 0:
                DataViewController.useHumanHeight = true
            case 1:
                DataViewController.useHumanHeight = false
            default:
                DataViewController.useHumanHeight = true
        }
    }
    
    @IBOutlet weak var heightPicker: UIPickerView!
    @IBOutlet weak var heightStackView: UIStackView!
    
    @IBOutlet weak var goBack: UIButton!

    @IBOutlet weak var sayThisTextField: UITextField!
    static var sayThisText = "Social distancing is for your safety. I haven't showered in weeks."
    

    @IBAction func goBack(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    @IBAction func textFieldChanged(_ sender: UITextField) {
        DataViewController.sayThisText = self.sayThisTextField.text ?? ""
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        DataViewController.sayThisText = self.sayThisTextField.text ?? ""
        textField.resignFirstResponder()
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.heightPicker.delegate = self
        self.heightPicker.dataSource = self
        self.sayThisTextField.delegate = self
        self.sayThisTextField.placeholder = DataViewController.sayThisText
        for feet in 0...7 {
            for inches in 0...11 {
                pickerData[1].append("\(feet)'\(inches)\"")
            }
        }
        if DataViewController.useHumanHeight {
            segmentedControlButton.selectedSegmentIndex = 0
        } else {
            segmentedControlButton.selectedSegmentIndex = 1
        }
        self.heightPicker.selectRow(DataViewController.chosenRow, inComponent: 1, animated: false)
    
    }
    

    // Number of columns of data
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if (component == 0) {
            return 1
        } else {
            return pickerData[1].count
        }
    }
    
    // The data to return for the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerData[component][row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        DataViewController.chosenRow = row
        let val = pickerData[component][row]
        let valArr = val.components(separatedBy: "'")
        DataViewController.chosenFeet = valArr[0]
        DataViewController.chosenInches = String(valArr[1].dropLast())
    }
 
    func pickerView(pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
    return 1.0
}
    
    func getHeight() -> Int {
        var height = (Int(DataViewController.chosenFeet) ?? 0) * 12 + (Int(DataViewController.chosenInches) ?? 0)
        if (DataViewController.useHumanHeight) {
            height = Int(Double(height) * DataViewController.shoulderBodyProportion)
        }
        return height
    }

}

class CameraViewController: UIViewController, ARSessionDelegate {

    @IBOutlet weak var arView: ARView!
    
    let dataViewController = DataViewController()
    
    let synthesizer = AVSpeechSynthesizer()
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    private var spinner: UIActivityIndicatorView!
    
    var motionManager = CMMotionManager()
    
    var windowOrientation: UIInterfaceOrientation {
        return view.window?.windowScene?.interfaceOrientation ?? .unknown
    }
    
    var ARSupported = true
    
    @IBOutlet weak var distanceMethodSegmentedControl: UISegmentedControl!
    
    var useARDistanceMethod = true

    @IBAction func distanceMethodSegmentedControlUpdate(_ sender: Any) {
        if self.ARSupported {
            switch distanceMethodSegmentedControl.selectedSegmentIndex {
                case 0:
                    self.useARDistanceMethod = true
                case 1:
                    self.useARDistanceMethod = false
                default:
                    self.useARDistanceMethod = true
            }
        } else {
            distanceMethodSegmentedControl.selectedSegmentIndex = 1
            self.useARDistanceMethod = false
        }
    }
    
    var yellingEnabled = false
    @IBAction func pressEnableYelling(_ sender: Any) {
        self.yellingEnabled = true
        
    }
    
    @IBAction func releaseEnableYelling(_ sender: Any) {
        self.yellingEnabled = false
        self.synthesizer.stopSpeaking(at: AVSpeechBoundary.immediate)
    }
    
    @IBAction func releaseEnableYellingDrag(_ sender: UIButton) {
        self.yellingEnabled = false
        self.synthesizer.stopSpeaking(at: AVSpeechBoundary.immediate)
    }
    
    let safeDistance = 6 * 12
    private var distanceString = "Distance: ???"
    private var distance = 99999.0
    private var lastDistance = 99999.0
    private var ARconsecutiveNonUpdates = 0
    private var lastARDistanceUpdateTime = CACurrentMediaTime() + 10
    private var pitch = 0.0 {
        didSet {
            self.updateDistance()
        }
    }
    private var ARDistance = 99999.0 {
        didSet {
            self.updateDistance()
            self.lastARDistanceUpdateTime = CACurrentMediaTime()
        }
    }
    
    func updateDistance() {
        if self.useARDistanceMethod {
            self.distance = self.ARDistance
        } else {
            self.distance = tan(self.pitch) * Double(self.dataViewController.getHeight())
        }
        if self.distance < 0 {
            self.distanceString = "Distance: ???"
        } else if ((self.distance > 1200) || ((CACurrentMediaTime() - self.lastARDistanceUpdateTime) > 3)) {
            self.distanceString = "Distance: N/A"
            self.distance = 1300.0
        } else {
            self.distanceString = "Distance: \(Int(self.distance/12))'\(Int(self.distance)%12)\""
        }
        DispatchQueue.main.async {
            self.distanceDisplay.text = self.distanceString
        }
        if (Int(self.distance) <= self.safeDistance) {
            DispatchQueue.main.async {
                self.distanceDisplay.backgroundColor = UIColor.red
            }
            if (!self.synthesizer.isSpeaking) && (self.yellingEnabled) {
                self.yell()
            }
        }  else if (Int(self.distance) > self.safeDistance) {
            DispatchQueue.main.async {
                self.distanceDisplay.backgroundColor = UIColor.black
            }
        }
    }
    
    @IBOutlet weak var distanceDisplay: UILabel!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.arView.session.delegate = self
        self.ARSupported = ARBodyTrackingConfiguration.isSupported


        // Run a body tracking configration.
        if self.ARSupported {
            let configuration = ARBodyTrackingConfiguration()
            arView.session.run(configuration)
        } else {
            let configuration = ARWorldTrackingConfiguration()
            arView.session.run(configuration)
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("uh oh, audio went wrong")
        }
        
        // Ensure to keep a strong reference to the motion manager otherwise you won't get updates
        
        if ARSupported {
            distanceMethodSegmentedControl.selectedSegmentIndex = 0
            self.useARDistanceMethod = true
        } else {
            distanceMethodSegmentedControl.selectedSegmentIndex = 1
            self.useARDistanceMethod = false
        }
        if motionManager.isDeviceMotionAvailable == true {
            motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
            motionManager.deviceMotionUpdateInterval = 0.1;

            let queue = OperationQueue()
            motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical,
               to: queue, withHandler: { (data, error) in
                 // Make sure the data is valid before accessing it.
                 if let validData = data {
                    // Get the attitude relative to the magnetic north reference frame.
                    self.pitch = validData.attitude.pitch
                 }
            })
            print("Device motion started")
        }
        else {
            print("Device motion unavailable");
        }
        
        DispatchQueue.main.async{
            self.distanceDisplay.text = self.distanceString
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        var minDistance = 100000.0
        if self.ARSupported {
            for anchor in anchors {
                guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
                let zDistance = Double(abs(bodyAnchor.transform.columns.3.z - (arView.session.currentFrame?.camera.transform.columns.3.z)!))
                let xDistance = Double(abs(bodyAnchor.transform.columns.3.x - (arView.session.currentFrame?.camera.transform.columns.3.x)!))
                let distance = sqrt(pow(xDistance, 2) + pow(zDistance, 2))
                if distance < minDistance {
                    minDistance = distance
                }
            }
        }
        self.ARDistance = minDistance * 39.3701 //convert meters to inches
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                print("good job")
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }

    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    private var setupResult: SessionSetupResult = .success
    
    @IBOutlet private weak var previewView: PreviewView!
    
    func yell() {
        let utterance = AVSpeechUtterance(string: DataViewController.sayThisText)
        self.synthesizer.speak(utterance)
    }
}
